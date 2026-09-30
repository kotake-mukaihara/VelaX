import 'dart:typed_data';
import 'dart:ui' as ui;

import 'crop_geometry.dart';
import 'erase_image_renderer.dart';

/// Shared by preview and export, including transform order and transparency.
void paintCropImage(
  ui.Canvas canvas,
  ui.Image image,
  CropState state, {
  List<EraseStroke> strokes = const [],
}) {
  canvas.save();
  canvas.translate(state.offset.dx, state.offset.dy);
  canvas.rotate(state.angle);
  canvas.scale(state.mirrored ? -state.scale : state.scale, state.scale);
  canvas.translate(-image.width / 2, -image.height / 2);
  if (strokes.isEmpty) {
    canvas.drawImage(
      image,
      ui.Offset.zero,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
  } else {
    paintErasedImage(canvas, image, strokes);
  }
  canvas.restore();
}

Future<Uint8List> renderCrop(
  ui.Image image,
  CropState state, {
  List<EraseStroke> strokes = const [],
}) async {
  final result = createCropImage(image, state, strokes: strokes);
  try {
    final bytes = await result.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) throw StateError('无法编码裁剪图片');
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    result.dispose();
  }
}

/// Defers rasterization without PNG encoding or CPU readback.
/// The caller owns and must dispose the returned image.
ui.Image createCropImage(
  ui.Image image,
  CropState state, {
  List<EraseStroke> strokes = const [],
}) {
  final width = (state.crop.width / state.scale).round().clamp(
    1,
    image.width + image.height,
  );
  final height = (state.crop.height / state.scale).round().clamp(
    1,
    image.width + image.height,
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(width / state.crop.width, height / state.crop.height);
  canvas.translate(-state.crop.left, -state.crop.top);
  paintCropImage(canvas, image, state, strokes: strokes);
  final picture = recorder.endRecording();
  try {
    return picture.toImageSync(width, height);
  } finally {
    picture.dispose();
  }
}
