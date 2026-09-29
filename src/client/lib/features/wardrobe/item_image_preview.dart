import 'dart:io';

import 'package:flutter/material.dart';

class ItemImagePreview extends StatelessWidget {
  const ItemImagePreview({super.key, required this.imagePath});
  final String imagePath;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.file(
              File(imagePath),
              fit: BoxFit.contain,
              semanticLabel: '单品照片',
              errorBuilder: (_, _, _) => const Center(child: Text('照片无法读取')),
            ),
          ),
        ),
      ),
    ),
  );
}
