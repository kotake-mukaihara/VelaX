import 'dart:io';

import 'package:flutter/material.dart';

import 'crop_image_page.dart';
import 'erase_image_page.dart';
import 'checkerboard_painter.dart';
import 'edit_item_page.dart';
import 'item_options.dart';

class EditImagePage extends StatefulWidget {
  const EditImagePage({super.key, required this.imagePath, this.options});

  final String imagePath;
  final ItemOptions? options;

  @override
  State<EditImagePage> createState() => _EditImagePageState();
}

class _EditImagePageState extends State<EditImagePage> {
  final _draft = ItemDraft();
  bool _confirmingExit = false;
  late String _imagePath = widget.imagePath;
  final _temporaryImages = <String>[];

  Future<void> _edit({bool erase = false}) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => erase
            ? EraseImagePage(imagePath: _imagePath)
            : CropImagePage(imagePath: _imagePath),
      ),
    );
    if (result == null) return;
    if (!mounted) {
      await _removeTemporaryImage(result);
      return;
    }
    setState(() {
      _temporaryImages.add(result);
      _imagePath = result;
    });
  }

  Future<void> _removeTemporaryImage(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // The operating system may already have cleared its temporary directory.
    }
  }

  @override
  void dispose() {
    for (final path in _temporaryImages) {
      _removeTemporaryImage(path);
    }
    super.dispose();
  }

  Future<void> _confirmExit() async {
    if (_confirmingExit) return;
    _confirmingExit = true;
    try {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('放弃编辑？'),
          content: const Text('返回上一级后，已编辑的内容不会保存。确定要返回吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('继续编辑'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('放弃编辑'),
            ),
          ],
        ),
      );
      if (discard == true && mounted) Navigator.of(context).pop();
    } finally {
      _confirmingExit = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<bool>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _confirmExit();
    },
    child: Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _confirmExit),
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
                          painter: const CheckerboardPainter(),
                          child: Image.file(
                            File(_imagePath),
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
                            ('一键抠图', Icons.content_cut),
                          ])
                            Expanded(
                              child: TextButton(
                                onPressed: action.$1 == '裁剪'
                                    ? () => _edit()
                                    : action.$1 == '擦除'
                                    ? () => _edit(erase: true)
                                    : null,
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
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () async {
                            final saved = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute(
                                    builder: (_) => EditItemPage(
                                      imagePath: _imagePath,
                                      options: widget.options,
                                      draft: _draft,
                                    ),
                                  ),
                                );
                            if (saved == true && context.mounted) {
                              Navigator.pop(context, true);
                            }
                          },
                          child: const Text('下一步'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
