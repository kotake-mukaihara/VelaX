import 'package:flutter/material.dart';

/// Draw the transparency grid as vector rectangles at any preview size.
class CheckerboardPainter extends CustomPainter {
  const CheckerboardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cellSize = 12.0;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final gray = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..isAntiAlias = false;
    for (var row = 0; row < (size.height / cellSize).ceil(); row++) {
      for (
        var column = row % 2;
        column < (size.width / cellSize).ceil();
        column += 2
      ) {
        canvas.drawRect(
          Rect.fromLTWH(column * cellSize, row * cellSize, cellSize, cellSize),
          gray,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CheckerboardPainter oldDelegate) => false;
}
