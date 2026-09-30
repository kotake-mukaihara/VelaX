import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'checkerboard_painter.dart';
import 'crop_geometry.dart';
import 'crop_image_renderer.dart';
import 'edit_session.dart';
import 'erase_image_renderer.dart';

const _blue = Color(0xFF438EFF);

class CropImagePage extends StatefulWidget {
  const CropImagePage({
    super.key,
    required this.imagePath,
    this.embedded = false,
    this.session,
  });
  final String imagePath;
  final bool embedded;
  final EditSession? session;

  @override
  State<CropImagePage> createState() => CropImagePageState();
}

class CropImagePageState extends State<CropImagePage>
    with SingleTickerProviderStateMixin {
  ColorScheme get _colors => Theme.of(context).colorScheme;
  Color get _background => _colors.surface;
  Color get _panel => _colors.surfaceContainerLow;
  Color get _gray => _colors.onSurfaceVariant;
  Color get _blue => _colors.primary;
  late final EditSession _session;
  ui.Image? get _image => _session.image;
  Future<void> get ready => _session.ready;
  String? get _error => _session.error;
  CropState? _state;
  bool _updatingCrop = false;
  CropState get _initial => _session.initialCrop;
  bool _saving = false;
  bool _confirming = false;
  bool _allowExit = false;
  CropState? _gestureBase;
  CropState? _segmentBase;
  final _pointers = <int, Offset>{};
  Offset? _dragStart;
  int? _handle;
  double _dragScale = 1;
  double _dragSpan = 0;
  late _CropView _dragView;
  late Rect _cameraFrom;
  late Rect _cameraTo;
  Offset? _snapFrom;
  double? _snapScaleFrom;
  late final AnimationController _animation =
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 230),
        value: 1,
      )..addListener(() {
        if (mounted) setState(() {});
      });

  Size get _imageSize =>
      Size(_image!.width.toDouble(), _image!.height.toDouble());
  bool get _dirty => _state != null && !_state!.sameAs(_initial);
  // Ignore transient overscroll/under-zoom until the gesture is committed.
  bool get _hasCommittedChanges =>
      _session.crop != null && !_session.crop!.sameAs(_initial);
  double get _progress => Curves.easeOutCubic.transform(_animation.value);
  Rect get _camera => Rect.lerp(_cameraFrom, _cameraTo, _progress)!;
  CropState get _visualState => _snapFrom == null
      ? _state!
      : _state!.copyWith(
          offset: Offset.lerp(_snapFrom, _state!.offset, _progress),
          scale: ui.lerpDouble(_snapScaleFrom, _state!.scale, _progress),
        );

  @override
  void initState() {
    super.initState();
    _session = widget.session ?? EditSession(widget.imagePath);
    _session.addListener(_sessionChanged);
    _initializeCrop();
  }

  void _initializeCrop() {
    if (_state == null && _session.crop != null) {
      _state = _session.crop;
      _cameraFrom = _cameraTo = _state!.crop;
    }
  }

  void _sessionChanged() {
    if (!mounted) return;
    setState(() {
      _initializeCrop();
      if (!_updatingCrop &&
          _gestureBase == null &&
          _session.crop != null &&
          !_state!.sameAs(_session.crop!)) {
        _animation.stop();
        _state = _session.crop;
        _cameraFrom = _cameraTo = _state!.crop;
        _snapFrom = null;
        _snapScaleFrom = null;
      }
    });
  }

  @override
  void dispose() {
    _session.removeListener(_sessionChanged);
    _animation.dispose();
    if (widget.session == null) _session.dispose();
    super.dispose();
  }

  void _record(CropState next) {
    _state = next;
    _updatingCrop = true;
    _session.setCrop(next);
    _updatingCrop = false;
  }

  // Settle only transient input; tool switches never render or replace images.
  void finishGesture() {
    if (_gestureBase == null || _state == null) return;
    _gestureBase = null;
    _segmentBase = null;
    _pointers.clear();
    _settle(coverCrop(_state!, _imageSize));
  }

  void _settle(CropState next, {bool record = true}) {
    final camera = _camera;
    final visual = _visualState;
    setState(() {
      if (record) {
        _record(next);
      } else {
        _state = next;
      }
      _cameraFrom = camera;
      _cameraTo = next.crop;
      _snapFrom = visual.offset;
      _snapScaleFrom = visual.scale;
    });
    _animation.forward(from: 0);
    if (MediaQuery.disableAnimationsOf(context)) _animation.value = 1;
  }

  void _change(CropState Function(CropState) change) {
    if (_gestureBase != null) return;
    _animation.value = 1;
    _settle(change(_state!));
  }

  void _undo(int direction) {
    if (_gestureBase != null) return;
    _updatingCrop = true;
    _session.undoCrop(direction);
    _updatingCrop = false;
    _settle(_session.crop!, record: false);
  }

  Future<void> _leave([String? result]) async {
    setState(() => _allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _back() async {
    if (_saving || _confirming || _allowExit) return;
    if (!_dirty) {
      await _leave();
      return;
    }
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _panel,
        title: Text(
          '确定放弃对图片的修改吗？',
          style: TextStyle(color: _colors.onSurface, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _gray),
            child: Text('放弃'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: _colors.onSurface),
            child: Text('取消'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (discard == true && mounted) await _leave();
  }

  Future<void> _complete() async {
    if (!_dirty || _saving) return;
    setState(() => _saving = true);
    try {
      final path = await exportImage();
      if (mounted) await _leave(path);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('裁剪保存失败，请重试')));
    }
  }

  Offset get _focalPoint =>
      _pointers.values.reduce((a, b) => a + b) / _pointers.length.toDouble();

  double get _span {
    final focal = _focalPoint;
    return _pointers.values.fold(0.0, (sum, p) => sum + (p - focal).distance) /
        _pointers.length;
  }

  // Each change of finger count starts a segment at the current transform.
  // All segments remain one history entry until the last finger lifts.
  void _rebaseGesture() {
    _segmentBase = _state;
    _dragStart = _focalPoint;
    _dragSpan = _span;
  }

  void _startPointer(PointerDownEvent event, Size viewport) {
    if (_pointers.isEmpty) {
      if (_gestureBase != null) return; // A slider gesture owns the editor.
      final visual = _visualState;
      final camera = _camera;
      _animation.stop();
      _state = visual;
      _cameraFrom = _cameraTo = camera;
      _snapFrom = null;
      _snapScaleFrom = null;
      _gestureBase = _session.crop;
      _dragView = _CropView(camera, viewport);
      _dragScale = _dragView.scale;
      _handle = null;
      var distance = 28.0;
      final points = _handles(_dragView.rect(_state!.crop));
      for (var i = 0; i < points.length; i++) {
        final d = (event.localPosition - points[i]).distance;
        if (d < distance) {
          distance = d;
          _handle = i;
        }
      }
    } else {
      // A second finger always manipulates the image, even on a handle.
      _handle = null;
    }
    _pointers[event.pointer] = event.localPosition;
    _rebaseGesture();
    setState(() {});
  }

  void _movePointer(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    final base = _segmentBase!;
    final focal = _focalPoint;
    final delta = (focal - _dragStart!) / _dragScale;
    setState(() {
      if (_handle == null) {
        final factor = _pointers.length > 1 && _dragSpan > 0.001
            ? _span / _dragSpan
            : 1.0;
        // Permit temporary under-zoom; coverage is restored only on release.
        final scale = (base.scale * factor).clamp(0.01, 100.0);
        final anchor = _dragView.unproject(_dragStart!);
        _state = base.copyWith(
          scale: scale,
          offset:
              anchor + delta + (base.offset - anchor) * (scale / base.scale),
        );
      } else {
        final minimum = math.min(48 / _dragScale, base.crop.shortestSide);
        _state = base.copyWith(
          crop: resizeCrop(base, _imageSize, _handle!, delta, minimum),
        );
      }
    });
  }

  void _endPointer(PointerUpEvent event) {
    if (_pointers.remove(event.pointer) == null) return;
    if (_pointers.isNotEmpty) {
      _rebaseGesture();
      return;
    }
    _gestureBase = null;
    _segmentBase = null;
    _settle(coverCrop(_state!, _imageSize));
  }

  void _cancelPointer(PointerCancelEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    final base = _gestureBase;
    _pointers.clear();
    _gestureBase = null;
    _segmentBase = null;
    if (base != null) _settle(base, record: false);
  }

  /// Exports applied edits without leaving the containing editor.
  Future<String> exportImage() {
    finishGesture();
    return _session.exportImage();
  }

  Widget _editor() => SafeArea(
    top: false,
    child: _state == null
        ? Center(
            child: _error == null
                ? CircularProgressIndicator(color: _gray)
                : Text(_error!, style: TextStyle(color: _gray)),
          )
        : AbsorbPointer(
            absorbing: _saving,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Keep a useful preview on short landscape windows as well.
                final controlsHeight = math.min(
                  238.0,
                  constraints.maxHeight * 0.48,
                );
                return Column(
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) => Listener(
                          key: ValueKey('crop-preview'),
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) =>
                              _startPointer(event, constraints.biggest),
                          onPointerMove: _movePointer,
                          onPointerUp: _endPointer,
                          onPointerCancel: _cancelPointer,
                          child: ClipRect(
                            child: CustomPaint(
                              size: constraints.biggest,
                              painter: const CheckerboardPainter(),
                              foregroundPainter: _CropPainter(
                                _image!,
                                _visualState,
                                _camera,
                                _session.erase.erased,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: controlsHeight,
                      child: ColoredBox(
                        color: _panel,
                        child: SingleChildScrollView(child: _controls()),
                      ),
                    ),
                  ],
                );
              },
            ),
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
            backgroundColor: _background,
            appBar: AppBar(
              backgroundColor: _background,
              surfaceTintColor: Colors.transparent,
              foregroundColor: _colors.onSurface,
              leading: BackButton(onPressed: _saving ? null : _back),
              actions: [
                TextButton(
                  key: ValueKey('crop-complete'),
                  onPressed: _dirty && !_saving && _gestureBase == null
                      ? _complete
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: _blue,
                    disabledForegroundColor: _colors.onSurface.withValues(
                      alpha: 0.45,
                    ),
                  ),
                  child: _saving
                      ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _colors.onSurface,
                          ),
                        )
                      : Text('完成'),
                ),
                SizedBox(width: 8),
              ],
            ),
            body: _editor(),
          ),
        );

  Widget _controls() => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 680),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
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
                      SizedBox(width: 12),
                      IconButton(
                        tooltip: '撤销',
                        onPressed: _session.canUndoCrop
                            ? () => _undo(-1)
                            : null,
                        color: _gray,
                        disabledColor: _colors.onSurface.withValues(
                          alpha: 0.38,
                        ),
                        icon: Icon(Icons.undo),
                      ),
                      IconButton(
                        tooltip: '恢复',
                        onPressed: _session.canRedoCrop ? () => _undo(1) : null,
                        color: _gray,
                        disabledColor: _colors.onSurface.withValues(
                          alpha: 0.38,
                        ),
                        icon: Icon(Icons.redo),
                      ),
                    ],
                  ),
                  if (_hasCommittedChanges)
                    TextButton(
                      onPressed: () => _change((_) => _initial),
                      style: TextButton.styleFrom(
                        foregroundColor: _colors.onSurface,
                      ),
                      child: Text('重置'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _circleButton(
                    '逆时针旋转90°',
                    Icons.rotate_90_degrees_ccw,
                    () => _change((s) => rotateCropLeft(s, _imageSize)),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${_state!.tilt.round()}°',
                          style: TextStyle(
                            color: _colors.onSurface,
                            fontSize: 14,
                          ),
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: _colors.outline,
                            inactiveTrackColor: _colors.onSurface.withValues(
                              alpha: 0.38,
                            ),
                            thumbColor: _blue,
                            overlayColor: _colors.onSurface.withValues(
                              alpha: 0.08,
                            ),
                            trackHeight: 2,
                            thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            showValueIndicator: ShowValueIndicator.never,
                          ),
                          child: Slider(
                            key: ValueKey('crop-tilt'),
                            label: '倾斜角度',
                            min: -45,
                            max: 45,
                            value: _state!.tilt,
                            semanticFormatterCallback: (v) =>
                                '倾斜 ${v.round()} 度',
                            onChangeStart: (_) {
                              _animation.value = 1;
                              _snapFrom = null;
                              _snapScaleFrom = null;
                              _gestureBase = _state;
                            },
                            onChanged: (v) => setState(() {
                              final base = _gestureBase ?? _state!;
                              _state = coverCrop(
                                base.copyWith(tilt: v.roundToDouble()),
                                _imageSize,
                              );
                            }),
                            onChangeEnd: (_) {
                              _gestureBase = null;
                              _settle(_state!);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  _circleButton(
                    '水平镜像翻转',
                    Icons.flip,
                    () => _change(mirrorCrop),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8),
            SizedBox(
              height: 82,
              child: ListView.separated(
                key: ValueKey('crop-ratios'),
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: cropRatios.length,
                separatorBuilder: (_, _) => SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final label = cropRatios.keys.elementAt(index);
                  final selected = _state!.ratio == label;
                  final ratio = label == '原始'
                      ? selectedRatio(
                          _state!.copyWith(ratio: label),
                          _imageSize,
                        )!
                      : cropRatios[label] ?? 1.2;
                  return Semantics(
                    selected: selected,
                    button: true,
                    label: '$label 裁剪比例',
                    child: InkWell(
                      key: ValueKey('crop-ratio-$label'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: () =>
                          _change((s) => selectCropRatio(s, label, _imageSize)),
                      child: SizedBox(
                        width: 58,
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 48,
                              padding: EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selected ? _blue : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Container(
                                  width: ratio >= 1 ? 32 : 28 * ratio,
                                  height: ratio >= 1 ? 32 / ratio : 28,
                                  decoration: BoxDecoration(
                                    color: _colors.outline,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              label,
                              style: TextStyle(color: _gray, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _circleButton(String tooltip, IconData icon, VoidCallback onPressed) =>
      IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: _colors.surfaceContainerHighest,
          foregroundColor: _gray,
          shape: CircleBorder(),
          minimumSize: Size.square(44),
        ),
        icon: Icon(icon, size: 23),
      );
}

List<Offset> _handles(Rect r) => [
  r.topLeft,
  r.topCenter,
  r.topRight,
  r.centerRight,
  r.bottomRight,
  r.bottomCenter,
  r.bottomLeft,
  r.centerLeft,
];

class _CropView {
  _CropView(this.camera, this.size);
  final Rect camera;
  final Size size;
  double get scale => math.min(
    math.max(1, size.width - 64) / camera.width,
    math.max(1, size.height - 48) / camera.height,
  );
  Offset point(Offset p) =>
      size.center(Offset.zero) + (p - camera.center) * scale;
  Offset unproject(Offset p) =>
      camera.center + (p - size.center(Offset.zero)) / scale;
  Rect rect(Rect r) => Rect.fromPoints(point(r.topLeft), point(r.bottomRight));
}

class _CropPainter extends CustomPainter {
  const _CropPainter(this.image, this.state, this.camera, this.strokes);
  final ui.Image image;
  final CropState state;
  final Rect camera;
  final List<EraseStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final view = _CropView(camera, size);
    final crop = view.rect(state.crop);
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(view.scale);
    canvas.translate(-camera.center.dx, -camera.center.dy);
    paintCropImage(canvas, image, state, strokes: strokes);
    canvas.restore();
    // Dim only image pixels outside the crop, preserving the checkerboard.
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(crop),
      Paint()
        ..color = const Color(0xA6171717)
        ..blendMode = BlendMode.srcATop,
    );
    canvas.restore();
    final grid = Paint()
      ..color = const Color(0x70FFFFFF)
      ..strokeWidth = 0.7;
    for (var i = 1; i <= 2; i++) {
      canvas.drawLine(
        Offset(crop.left + crop.width * i / 3, crop.top),
        Offset(crop.left + crop.width * i / 3, crop.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(crop.left, crop.top + crop.height * i / 3),
        Offset(crop.right, crop.top + crop.height * i / 3),
        grid,
      );
    }
    canvas.drawRect(
      crop,
      Paint()
        ..color = _blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final grip = Paint()
      ..color = _blue
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    final length = math.min(18.0, crop.shortestSide / 4);
    for (final corner in cropCorners(crop)) {
      final dx = corner.dx == crop.left ? length : -length;
      final dy = corner.dy == crop.top ? length : -length;
      canvas.drawLine(corner, corner + Offset(dx, 0), grip);
      canvas.drawLine(corner, corner + Offset(0, dy), grip);
    }
    for (final point in [crop.topCenter, crop.bottomCenter]) {
      canvas.drawLine(
        point - Offset(length / 2, 0),
        point + Offset(length / 2, 0),
        grip,
      );
    }
    for (final point in [crop.centerLeft, crop.centerRight]) {
      canvas.drawLine(
        point - Offset(0, length / 2),
        point + Offset(0, length / 2),
        grip,
      );
    }
  }

  @override
  bool shouldRepaint(_CropPainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.image != image ||
      oldDelegate.state != state ||
      oldDelegate.camera != camera;
}
