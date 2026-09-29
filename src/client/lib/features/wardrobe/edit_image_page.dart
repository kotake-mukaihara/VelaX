import 'dart:io';

import 'package:flutter/material.dart';

import 'crop_image_page.dart';
import 'erase_image_page.dart';
import 'eraser_icon.dart';

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

  final _cropKey = GlobalKey<CropImagePageState>();
  final _eraseKey = GlobalKey<EraseImagePageState>();
  bool _erase = false;
  bool _busy = false;

  Future<bool> _commit() async {
    try {
      final path = _erase
          ? await _eraseKey.currentState?.exportImage()
          : await _cropKey.currentState?.exportImage();
      if (path != null && path != _imagePath) {
        _temporaryImages.add(path);
        _imagePath = path;
      }
      return mounted;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('图片保存失败，请重试')));
      }
      return false;
    }
  }

  Future<void> _selectTool(bool erase) async {
    if (_busy || erase == _erase) return;
    setState(() => _busy = true);
    try {
      await Future.wait([
        _cropKey.currentState!.ready,
        _eraseKey.currentState!.ready,
      ]);
      final image = _erase
          ? await _eraseKey.currentState!.shareImage()
          : await _cropKey.currentState!.shareImage();
      if (!mounted) {
        image?.dispose();
        return;
      }
      if (image != null) {
        if (erase) {
          _eraseKey.currentState!.replaceImage(image);
        } else {
          _cropKey.currentState!.replaceImage(image);
        }
      }
      setState(() => _erase = erase);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('图片处理失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    if (_busy) return;
    setState(() => _busy = true);
    if (!await _commit()) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditItemPage(
          imagePath: _imagePath,
          options: widget.options,
          draft: _draft,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved == true) Navigator.pop(context, true);
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        leading: BackButton(onPressed: _confirmExit),
        title: const Text('编辑图片'),
        actions: [
          TextButton(
            key: const ValueKey('edit-image-next'),
            onPressed: _next,
            child: const Text('下一步'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: AbsorbPointer(
                absorbing: _busy,
                child: IndexedStack(
                  index: _erase ? 1 : 0,
                  children: [
                    CropImagePage(
                      key: _cropKey,
                      imagePath: widget.imagePath,
                      embedded: true,
                    ),
                    EraseImagePage(
                      key: _eraseKey,
                      imagePath: widget.imagePath,
                      embedded: true,
                    ),
                  ],
                ),
              ),
            ),
            NavigationBar(
              selectedIndex: _erase ? 1 : 0,
              onDestinationSelected: (index) => _selectTool(index == 1),
              backgroundColor: Theme.of(context)
                  .colorScheme
                  .surfaceContainerLow,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.crop), label: '裁剪'),
                NavigationDestination(
                  icon: EraserIcon(),
                  selectedIcon: EraserIcon(filled: true),
                  label: '擦除',
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
