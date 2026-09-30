import 'package:flutter/material.dart';

/// Uses the navigation icon theme for both selected and unselected states.
class EraserIcon extends StatelessWidget {
  const EraserIcon({super.key, this.filled = false});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    return SizedBox.square(
      dimension: theme.size ?? 24,
      child: CustomPaint(
        painter: _EraserPainter(theme.color ?? Colors.black, filled),
      ),
    );
  }
}

class _EraserPainter extends CustomPainter {
  const _EraserPainter(this.color, this.filled);
  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final outline = Path()
      ..moveTo(3, 14)
      ..lineTo(13, 4)
      ..quadraticBezierTo(14, 3, 15, 4)
      ..lineTo(21, 10)
      ..quadraticBezierTo(22, 11, 21, 12)
      ..lineTo(13, 20)
      ..lineTo(8, 20)
      ..lineTo(3, 15)
      ..close();
    final ink = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (filled) {
      canvas.drawPath(
        Path()
          ..moveTo(8, 9)
          ..lineTo(14, 3)
          ..lineTo(22, 11)
          ..lineTo(16, 17)
          ..close(),
        Paint()..color = color,
      );
    }
    canvas.drawPath(outline, ink);
    canvas.drawLine(const Offset(8, 9), const Offset(16, 17), ink);
    canvas.drawLine(const Offset(13, 20), const Offset(21, 20), ink);
  }

  @override
  bool shouldRepaint(_EraserPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.filled != filled;
}
