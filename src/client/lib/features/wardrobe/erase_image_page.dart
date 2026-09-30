import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'checkerboard_painter.dart';
import 'erase_image_renderer.dart';
import 'crop_geometry.dart';
import 'crop_image_renderer.dart';
import 'edit_session.dart';

class EraseImagePage extends StatefulWidget {
  const EraseImagePage({
    super.key,
    required this.imagePath,
    this.embedded = false,
    this.session,
  });
  final String imagePath;
  final bool embedded;
  final EditSession? session;

  @override
  State<EraseImagePage> createState() => EraseImagePageState();
}

class EraseImagePageState extends State<EraseImagePage> {
  ColorScheme get _colors => Theme.of(context).colorScheme;
  late final EditSession _session;
  ui.Image? get _image => _session.image;
  Future<void> get ready => _session.ready;
  String? get _error => _session.error;
  EraseState get _state => _session.erase;
  CropState? _lastCrop;
  List<Offset>? _strokeClip;
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
  Rect get _bounds => _session.crop!.crop;
  double get _fit => math.min(
    _viewport.width / _bounds.width,
    _viewport.height / _bounds.height,
  );
  double get _scale => _fit * _zoom;
  Offset get _origin =>
      _viewport.center(Offset.zero) + _pan - _bounds.center * _scale;
  Offset _unproject(Offset point) =>
      _session.toSource((point - _origin) / _scale);
  Offset get _focal =>
      _pointers.values.reduce((a, b) => a + b) / _pointers.length.toDouble();
  double get _span =>
      _pointers.values.fold(0.0, (s, p) => s + (p - _focal).distance) /
      _pointers.length;

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? EditSession(widget.imagePath);
    _lastCrop = _session.crop;
    _session.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!mounted) return;
    setState(() {
      if (!identical(_lastCrop, _session.crop)) {
        _lastCrop = _session.crop;
        _zoom = 1;
        _pan = Offset.zero;
        _drawing = null;
        _pointers.clear();
      }
    });
  }

  @override
  void dispose() {
    _session.removeListener(_sessionChanged);
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  void _restore(int direction) {
    _session.undoErase(direction);
    setState(() {
      _zoom = 1;
      _pan = Offset.zero;
    });
  }

  void _applyErase() {
    if (!_idle || _state.pending.isEmpty) return;
    _session.applyErase();
    setState(() {
      _zoom = 1;
      _pan = Offset.zero;
    });
  }

  void finishGesture() {
    setState(() {
      _drawing = null;
      _pointers.clear();
      _transforming = false;
    });
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
        _strokeWidth = _brush / (_scale * _session.crop!.scale);
        _strokeClip = _session.selectionClip;
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
          _session.addSelection(
            EraseStroke(points, _strokeWidth, clip: _strokeClip),
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
    try {
      final path = await exportImage();
      if (mounted) await _leave(path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('擦除保存失败，请重试')));
    }
  }

  Future<String> exportImage() => _session.exportImage();

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
                                _session.crop!,
                                _origin,
                                _scale,
                                _drawing == null
                                    ? null
                                    : EraseStroke(
                                        _drawing!,
                                        _strokeWidth,
                                        clip: _strokeClip,
                                      ),
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
                          onPressed: _idle && _session.canUndoErase
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
                          onPressed: _idle && _session.canRedoErase
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
                              ? _applyErase
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
                                  _session.resetErase();
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
    this.crop,
    this.origin,
    this.scale,
    this.drawing,
  );
  final ui.Image image;
  final EraseState state;
  final CropState crop;
  final Offset origin;
  final double scale;
  final EraseStroke? drawing;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scale);
    canvas.clipRect(crop.crop);
    paintCropImage(canvas, image, crop, strokes: state.erased);
    canvas.translate(crop.offset.dx, crop.offset.dy);
    canvas.rotate(crop.angle);
    canvas.scale(crop.mirrored ? -crop.scale : crop.scale, crop.scale);
    canvas.translate(-image.width / 2, -image.height / 2);
    paintEraseStrokes(canvas, [
      ...state.pending,
      ?drawing,
    ], Paint()..color = const Color(0x88438EFF));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ErasePainter oldDelegate) => true;
}
