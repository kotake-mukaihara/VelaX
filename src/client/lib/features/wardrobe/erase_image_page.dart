import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'checkerboard_painter.dart';
import 'erase_image_renderer.dart';

class EraseImagePage extends StatefulWidget {
  const EraseImagePage({super.key, required this.imagePath});
  final String imagePath;

  @override
  State<EraseImagePage> createState() => _EraseImagePageState();
}

class _EraseState {
  const _EraseState({this.erased = const [], this.pending = const []});
  final List<EraseStroke> erased;
  final List<EraseStroke> pending;
  bool get dirty => erased.isNotEmpty || pending.isNotEmpty;
}

class _EraseImagePageState extends State<EraseImagePage> {
  ui.Image? _image;
  String? _error;
  final _history = <_EraseState>[const _EraseState()];
  int _index = 0;
  _EraseState get _state => _history[_index];
  double _brush = 40;
  double _zoom = 1;
  Offset _pan = Offset.zero;
  final _pointers = <int, Offset>{};
  List<Offset>? _drawing;
  double _strokeWidth = 40;
  bool _transforming = false;
  bool _saving = false;
  bool _allowExit = false;
  bool _confirming = false;
  double _baseZoom = 1;
  double _baseSpan = 0;
  Offset _basePan = Offset.zero;
  Offset _baseFocal = Offset.zero;
  Size _viewport = Size.zero;
  bool get _idle => !_saving && _pointers.isEmpty;
  double get _fit => math.min(
    _viewport.width / _image!.width,
    _viewport.height / _image!.height,
  );
  double get _scale => _fit * _zoom;
  Offset get _origin =>
      _viewport.center(Offset.zero) +
      _pan -
      Offset(_image!.width / 2, _image!.height / 2) * _scale;
  Offset _unproject(Offset point) => (point - _origin) / _scale;
  Offset get _focal =>
      _pointers.values.reduce((a, b) => a + b) / _pointers.length.toDouble();
  double get _span =>
      _pointers.values.fold(0.0, (s, p) => s + (p - _focal).distance) /
      _pointers.length;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final codec = await ui.instantiateImageCodec(
        await File(widget.imagePath).readAsBytes(),
      );
      late ui.Image image;
      try {
        image = (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() => _image = image);
    } catch (_) {
      if (mounted) setState(() => _error = '照片无法读取，请返回重新选择');
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  void _record(_EraseState state) {
    _history.removeRange(_index + 1, _history.length);
    _history.add(state);
    _index++;
  }

  void _rebase() {
    _baseZoom = _zoom;
    _basePan = _pan;
    _baseFocal = _focal;
    _baseSpan = _span;
  }

  void _down(PointerDownEvent event) {
    if (_saving) return;
    setState(() {
      _pointers[event.pointer] = event.localPosition;
      if (_pointers.length == 1) {
        _transforming = false;
        _strokeWidth = _brush / _scale;
        _drawing = [_unproject(event.localPosition)];
      } else {
        _drawing = null;
        _transforming = true;
        _rebase();
      }
    });
  }

  void _move(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    setState(() {
      _pointers[event.pointer] = event.localPosition;
      if (_transforming) {
        if (_pointers.length < 2) return;
        _zoom = (_baseZoom * (_baseSpan > 0 ? _span / _baseSpan : 1)).clamp(
          0.25,
          12.0,
        );
        final center = _viewport.center(Offset.zero);
        _pan =
            _focal -
            center -
            (_baseFocal - center - _basePan) * (_zoom / _baseZoom);
      } else {
        _drawing?.add(_unproject(event.localPosition));
      }
    });
  }

  void _up(PointerUpEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    setState(() {
      _pointers.remove(event.pointer);
      if (_pointers.isNotEmpty) {
        _rebase();
        return;
      }
      final points = _drawing;
      if (points != null) {
        final bounds = Rect.fromLTWH(
          0,
          0,
          _image!.width.toDouble(),
          _image!.height.toDouble(),
        );
        // Ignore gestures wholly outside the photograph.
        final strokeBounds = points.fold<Rect>(
          Rect.fromCircle(center: points.first, radius: _strokeWidth / 2),
          (r, point) => r.expandToInclude(
            Rect.fromCircle(center: point, radius: _strokeWidth / 2),
          ),
        );
        if (bounds.overlaps(strokeBounds)) {
          _record(
            _EraseState(
              erased: _state.erased,
              pending: [..._state.pending, EraseStroke(points, _strokeWidth)],
            ),
          );
        }
      }
      _drawing = null;
      _transforming = false;
    });
  }

  Future<void> _leave([String? path]) async {
    setState(() => _allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, path);
  }

  Future<void> _back() async {
    if (_saving || _confirming || _allowExit) return;
    if (!_state.dirty) {
      await _leave();
      return;
    }
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确定放弃对图片的修改吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('放弃'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (discard == true && mounted) await _leave();
  }

  Future<void> _complete() async {
    if (!_idle) return;
    if (_state.erased.isEmpty) {
      await _leave();
      return;
    }
    setState(() => _saving = true);
    File? output;
    try {
      final bytes = await renderErasedImage(_image!, _state.erased);
      final directory = await getTemporaryDirectory();
      output = File(
        p.join(directory.path, 'velax_erase_${const Uuid().v4()}.png'),
      );
      await output.writeAsBytes(bytes, flush: true);
      if (!mounted) {
        await output.delete();
        return;
      }
      await _leave(output.path);
    } catch (_) {
      if (output != null && await output.exists()) await output.delete();
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('擦除保存失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<String>(
    canPop: _allowExit,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _back();
    },
    child: Scaffold(
      backgroundColor: const Color(0xFF171717),
      appBar: AppBar(
        backgroundColor: const Color(0xFF171717),
        foregroundColor: Colors.white,
        leading: BackButton(onPressed: _back),
        actions: [
          TextButton(
            key: const ValueKey('erase-complete'),
            onPressed: _image != null && _idle ? _complete : null,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('完成'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _image == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                      ),
              )
            : Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          _viewport = constraints.biggest;
                          return Listener(
                            key: const ValueKey('erase-preview'),
                            behavior: HitTestBehavior.opaque,
                            onPointerDown: _down,
                            onPointerMove: _move,
                            onPointerUp: _up,
                            onPointerCancel: (_) => setState(() {
                              _pointers.clear();
                              _drawing = null;
                              _transforming = false;
                            }),
                            child: ClipRect(
                              child: CustomPaint(
                                size: constraints.biggest,
                                painter: const CheckerboardPainter(),
                                foregroundPainter: _ErasePainter(
                                  _image!,
                                  _state,
                                  _origin,
                                  _scale,
                                  _drawing == null
                                      ? null
                                      : EraseStroke(_drawing!, _strokeWidth),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    color: const Color(0xFF222222),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.edit,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      showValueIndicator:
                                          ShowValueIndicator.onlyForDiscrete,
                                    ),
                                    child: Slider(
                                      key: const ValueKey('erase-brush'),
                                      min: 20,
                                      max: 100,
                                      divisions: 8,
                                      value: _brush,
                                      label: '${_brush.round()}',
                                      semanticFormatterCallback: (v) =>
                                          '笔刷粗度 ${v.round()}',
                                      onChanged: _idle
                                          ? (value) =>
                                                setState(() => _brush = value)
                                          : null,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.edit,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: '撤销',
                                  color: Colors.white,
                                  onPressed: _idle && _index > 0
                                      ? () => setState(() => _index--)
                                      : null,
                                  icon: const Icon(Icons.undo),
                                ),
                                IconButton(
                                  tooltip: '恢复',
                                  color: Colors.white,
                                  onPressed:
                                      _idle && _index < _history.length - 1
                                      ? () => setState(() => _index++)
                                      : null,
                                  icon: const Icon(Icons.redo),
                                ),
                                Expanded(
                                  child: Center(
                                    child:
                                        _state.dirty ||
                                            _zoom != 1 ||
                                            _pan != Offset.zero
                                        ? TextButton(
                                            onPressed: _idle
                                                ? () => setState(() {
                                                    if (_state.dirty) {
                                                      _record(
                                                        const _EraseState(),
                                                      );
                                                    }
                                                    _zoom = 1;
                                                    _pan = Offset.zero;
                                                  })
                                                : null,
                                            child: const Text('重置'),
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                                FilledButton(
                                  key: const ValueKey('erase-apply'),
                                  onPressed: _idle && _state.pending.isNotEmpty
                                      ? () => setState(
                                          () => _record(
                                            _EraseState(
                                              erased: [
                                                ..._state.erased,
                                                ..._state.pending,
                                              ],
                                            ),
                                          ),
                                        )
                                      : null,
                                  child: const Text('擦除'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

class _ErasePainter extends CustomPainter {
  const _ErasePainter(
    this.image,
    this.state,
    this.origin,
    this.scale,
    this.drawing,
  );
  final ui.Image image;
  final _EraseState state;
  final Offset origin;
  final double scale;
  final EraseStroke? drawing;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    canvas.clipRect(
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    );
    paintErasedImage(canvas, image, state.erased);
    paintEraseStrokes(canvas, [
      ...state.pending,
      ?drawing,
    ], Paint()..color = const Color(0x88438EFF));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ErasePainter oldDelegate) => true;
}
