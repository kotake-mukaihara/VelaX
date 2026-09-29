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
  List<EraseStroke> strokes, {
  ui.Rect? bounds,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  if (bounds != null) canvas.translate(-bounds.left, -bounds.top);
  paintErasedImage(canvas, image, strokes);
  final picture = recorder.endRecording();
  try {
    final result = await picture.toImage(
      bounds?.width.toInt() ?? image.width,
      bounds?.height.toInt() ?? image.height,
    );
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
