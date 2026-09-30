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
  const EraseImagePage({
    super.key,
    required this.imagePath,
    this.embedded = false,
  });
  final String imagePath;
  final bool embedded;

  @override
  State<EraseImagePage> createState() => EraseImagePageState();
}

class _EraseState {
  const _EraseState({
    this.erased = const [],
    this.pending = const [],
    this.bounds,
  });
  final Rect? bounds;
  final List<EraseStroke> erased;
  final List<EraseStroke> pending;
  bool get dirty => erased.isNotEmpty || pending.isNotEmpty;
}

class EraseImagePageState extends State<EraseImagePage> {
  ColorScheme get _colors => Theme.of(context).colorScheme;
  ui.Image? _image;
  late final Future<void> ready;
  List<EraseStroke> _sharedStrokes = const [];
  bool _receivedImage = false;
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
  bool get _idle => _image != null && !_saving && _pointers.isEmpty;
  Rect get _bounds =>
      _state.bounds ??
      Rect.fromLTWH(0, 0, _image!.width.toDouble(), _image!.height.toDouble());
  Future<void>? _applying;
  double get _fit => math.min(
    _viewport.width / _bounds.width,
    _viewport.height / _bounds.height,
  );
  double get _scale => _fit * _zoom;
  Offset get _origin =>
      _viewport.center(Offset.zero) + _pan - _bounds.center * _scale;
  Offset _unproject(Offset point) => (point - _origin) / _scale;
  Offset get _focal =>
      _pointers.values.reduce((a, b) => a + b) / _pointers.length.toDouble();
  double get _span =>
      _pointers.values.fold(0.0, (s, p) => s + (p - _focal).distance) /
      _pointers.length;

  @override
  void initState() {
    super.initState();
    ready = _load();
  }

  Future<ui.Image?> shareImage() async {
    await ready;
    await _applying;
    if (_image == null || identical(_sharedStrokes, _state.erased)) return null;
    final codec = await ui.instantiateImageCodec(
      await renderErasedImage(_image!, _state.erased, bounds: _state.bounds),
    );
    try {
      final image = (await codec.getNextFrame()).image;
      _sharedStrokes = _state.erased;
      return image;
    } finally {
      codec.dispose();
    }
  }

  void replaceImage(ui.Image image) {
    final old = _image;
    setState(() {
      _image = image;
      _error = null;
      _receivedImage = true;
      _history
        ..clear()
        ..add(const _EraseState());
      _index = 0;
      _sharedStrokes = _state.erased;
      _zoom = 1;
      _pan = Offset.zero;
      _drawing = null;
      _pointers.clear();
    });
    old?.dispose();
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

  void _restore(int direction) {
    setState(() {
      _index += direction;
      _zoom = 1;
      _pan = Offset.zero;
    });
  }

  Future<void> _applyErase() async {
    if (!_idle || _state.pending.isEmpty) return;
    setState(() => _saving = true);
    try {
      final strokes = [..._state.erased, ..._state.pending];
      final bounds = await erasedContentBounds(_image!, strokes);
      if (!mounted) return;
      setState(() {
        _record(_EraseState(erased: strokes, bounds: bounds));
        _zoom = 1;
        _pan = Offset.zero;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('擦除失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        // Ignore gestures wholly outside the image.
        final strokeBounds = points.fold<Rect>(
          Rect.fromCircle(center: points.first, radius: _strokeWidth / 2),
          (r, point) => r.expandToInclude(
            Rect.fromCircle(center: point, radius: _strokeWidth / 2),
          ),
        );
        if (bounds.overlaps(strokeBounds)) {
          _record(
            _EraseState(
              bounds: _state.bounds,
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
      final bytes = await renderErasedImage(
        _image!,
        _state.erased,
        bounds: _state.bounds,
      );
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

  /// Exports applied edits without leaving the containing editor.
  Future<String> exportImage() async {
    await _applying;
    if (_image == null || (_state.erased.isEmpty && !_receivedImage)) {
      return widget.imagePath;
    }
    final bytes = await renderErasedImage(
      _image!,
      _state.erased,
      bounds: _state.bounds,
    );
    final directory = await getTemporaryDirectory();
    final output = File(
      p.join(directory.path, 'velax_Erase_${const Uuid().v4()}.png'),
    );
    await output.writeAsBytes(bytes, flush: true);
    return output.path;
  }

  Widget _editor() => SafeArea(
    child: Column(
      children: [
        Expanded(
          child: _image == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Text(
                          _error!,
                          style: TextStyle(color: _colors.onSurface),
                        ),
                )
              : CustomPaint(
                  painter: const CheckerboardPainter(),
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
        ),
        Container(
          color: _colors.surfaceContainerLow,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: '撤销',
                          disabledColor: _colors.onSurface.withValues(
                            alpha: 0.45,
                          ),
                          color: _colors.onSurfaceVariant,
                          onPressed: _idle && _index > 0
                              ? () => _restore(-1)
                              : null,
                          icon: const Icon(Icons.undo),
                        ),
                        IconButton(
                          tooltip: '恢复',
                          disabledColor: _colors.onSurface.withValues(
                            alpha: 0.45,
                          ),
                          color: _colors.onSurfaceVariant,
                          onPressed: _idle && _index < _history.length - 1
                              ? () => _restore(1)
                              : null,
                          icon: const Icon(Icons.redo),
                        ),
                        const Spacer(),
                        FilledButton(
                          key: const ValueKey('erase-apply'),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(64, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            disabledForegroundColor: _colors.onSurface
                                .withValues(alpha: 0.45),
                            disabledBackgroundColor:
                                _colors.surfaceContainerHighest,
                          ),
                          onPressed: _idle && _state.pending.isNotEmpty
                              ? () {
                                  _applying = _applyErase();
                                }
                              : null,
                          child: const Text('擦除'),
                        ),
                      ],
                    ),
                    if (_state.dirty || _zoom != 1 || _pan != Offset.zero)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: _colors.onSurface,
                        ),
                        onPressed: _idle
                            ? () => setState(() {
                                if (_state.dirty) {
                                  _record(const _EraseState());
                                }
                                _zoom = 1;
                                _pan = Offset.zero;
                              })
                            : null,
                        child: const Text('重置'),
                      ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(Icons.edit, size: 18, color: _colors.onSurfaceVariant),
                  Expanded(
                    child: Slider(
                      key: const ValueKey('erase-brush'),
                      min: 20,
                      max: 100,
                      divisions: 8,
                      value: _brush,
                      label: '${_brush.round()}',
                      semanticFormatterCallback: (v) => '笔刷粗度 ${v.round()}',
                      onChanged: _idle
                          ? (value) => setState(() => _brush = value)
                          : null,
                    ),
                  ),
                  Icon(Icons.edit, size: 32, color: _colors.onSurfaceVariant),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    key: const ValueKey('erase-cutout'),
                    tooltip: '一键抠图',
                    style: IconButton.styleFrom(
                      shape: const CircleBorder(),
                      disabledBackgroundColor: _colors.surfaceContainerHighest,
                      disabledForegroundColor: _colors.onSurface.withValues(
                        alpha: 0.45,
                      ),
                    ),
                    onPressed: null,
                    icon: const Icon(Icons.auto_fix_high),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => widget.embedded
      ? _editor()
      : PopScope<String>(
          canPop: _allowExit,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _back();
          },
          child: Scaffold(
            backgroundColor: _colors.surface,
            appBar: AppBar(
              backgroundColor: _colors.surface,
              foregroundColor: _colors.onSurface,
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
            body: _editor(),
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
