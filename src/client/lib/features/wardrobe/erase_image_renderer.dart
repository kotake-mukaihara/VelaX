import 'dart:typed_data';
import 'dart:ui' as ui;

class EraseStroke {
  EraseStroke(List<ui.Offset> points, this.width, {List<ui.Offset>? clip})
    : points = List.unmodifiable(points),
      clip = clip == null ? null : List.unmodifiable(clip);
  final List<ui.Offset> points;
  final double width;
  final List<ui.Offset>? clip;
}

void paintEraseStrokes(
  ui.Canvas canvas,
  List<EraseStroke> strokes,
  ui.Paint paint,
) {
  for (final stroke in strokes) {
    canvas.save();
    if (stroke.clip != null) {
      canvas.clipPath(ui.Path()..addPolygon(stroke.clip!, true));
    }
    paint.strokeWidth = stroke.width;
    paint.strokeCap = ui.StrokeCap.round;
    paint.strokeJoin = ui.StrokeJoin.round;
    if (stroke.points.length == 1) {
      paint.style = ui.PaintingStyle.fill;
      canvas.drawCircle(stroke.points.first, stroke.width / 2, paint);
    } else {
      paint.style = ui.PaintingStyle.stroke;
      final path = ui.Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (final point in stroke.points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }
}

void paintErasedImage(
  ui.Canvas canvas,
  ui.Image image,
  List<EraseStroke> strokes,
) {
  final bounds = ui.Rect.fromLTWH(
    0,
    0,
    image.width.toDouble(),
    image.height.toDouble(),
  );
  canvas.saveLayer(bounds, ui.Paint());
  canvas.drawImage(
    image,
    ui.Offset.zero,
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  paintEraseStrokes(
    canvas,
    strokes,
    ui.Paint()..blendMode = ui.BlendMode.clear,
  );
  canvas.restore();
}

Future<Uint8List> renderErasedImage(
  ui.Image image,
  List<EraseStroke> strokes, {
  ui.Rect? bounds,
}) async {
  final result = createErasedImage(image, strokes, bounds: bounds);
  try {
    final data = await result.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('无法编码图片');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    result.dispose();
  }
}

/// Defers rasterization without PNG encoding or CPU readback.
/// The caller owns and must dispose the returned image.
ui.Image createErasedImage(
  ui.Image image,
  List<EraseStroke> strokes, {
  ui.Rect? bounds,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (bounds != null) canvas.translate(-bounds.left, -bounds.top);
  paintErasedImage(canvas, image, strokes);
  final picture = recorder.endRecording();
  try {
    return picture.toImageSync(
      bounds?.width.toInt() ?? image.width,
      bounds?.height.toInt() ?? image.height,
    );
  } finally {
    picture.dispose();
  }
}

/// Pixel bounds of the remaining content, in original image coordinates.
/// Keep the original canvas when everything is transparent so it stays editable.
Future<ui.Rect> erasedContentBounds(
  ui.Image image,
  List<EraseStroke> strokes,
) async {
  final recorder = ui.PictureRecorder();
  paintErasedImage(ui.Canvas(recorder), image, strokes);
  final picture = recorder.endRecording();
  try {
    final result = await picture.toImage(image.width, image.height);
    try {
      final data = await result.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) throw StateError('无法读取图片');
      var left = image.width, top = image.height, right = -1, bottom = -1;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (data.getUint8((y * image.width + x) * 4 + 3) == 0) continue;
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
      return right < left
          ? ui.Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            )
          : ui.Rect.fromLTRB(
              left.toDouble(),
              top.toDouble(),
              right + 1.0,
              bottom + 1.0,
            );
    } finally {
      result.dispose();
    }
  } finally {
    picture.dispose();
  }
}
