import 'dart:io';

import 'package:flutter/material.dart';

class EditImagePage extends StatelessWidget {
  const EditImagePage({super.key, required this.imagePath});

  final String imagePath;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      title: const Text('编辑图片'),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SizedBox.expand(
                    child: ClipRect(
                      child: CustomPaint(
                        painter: const _CheckerboardPainter(),
                        child: Image.file(
                          File(imagePath),
                          fit: BoxFit.contain,
                          semanticLabel: '待编辑的衣物照片',
                          errorBuilder: (_, _, _) =>
                              const Center(child: Text('照片无法读取，请返回重新选择')),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final action in [
                          ('裁剪', Icons.crop),
                          ('擦除', Icons.auto_fix_normal_outlined),
                          ('抠图', Icons.content_cut),
                        ])
                          Expanded(
                            child: TextButton(
                              onPressed: null,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(action.$2),
                                  const SizedBox(height: 8),
                                  Text(action.$1),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(
                      width: double.infinity,
                      child: FilledButton(onPressed: null, child: Text('下一步')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Draw the transparency grid as vector rectangles at any preview size.
class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter();

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
  bool shouldRepaint(_CheckerboardPainter oldDelegate) => false;
}
