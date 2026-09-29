import 'dart:typed_data';
import 'dart:ui' as ui;

class EraseStroke {
  EraseStroke(List<ui.Offset> points, this.width)
    : points = List.unmodifiable(points);
  final List<ui.Offset> points;
  final double width;
}

void paintEraseStrokes(
  ui.Canvas canvas,
  List<EraseStroke> strokes,
  ui.Paint paint,
) {
  for (final stroke in strokes) {
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
  canvas.drawImage(image, ui.Offset.zero, ui.Paint());
  paintEraseStrokes(
    canvas,
    strokes,
    ui.Paint()..blendMode = ui.BlendMode.clear,
  );
  canvas.restore();
}

Future<Uint8List> renderErasedImage(
  ui.Image image,
  List<EraseStroke> strokes,
) async {
  final recorder = ui.PictureRecorder();
  paintErasedImage(ui.Canvas(recorder), image, strokes);
  final picture = recorder.endRecording();
  try {
    final result = await picture.toImage(image.width, image.height);
    try {
      final data = await result.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('无法编码图片');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      result.dispose();
    }
  } finally {
    picture.dispose();
  }
}
