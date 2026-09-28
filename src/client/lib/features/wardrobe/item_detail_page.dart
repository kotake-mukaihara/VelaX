import 'package:flutter/material.dart';

import '../../domain/models/clothing_item.dart';
import 'edit_item_page.dart';
import 'item_image_preview.dart';
import 'item_options.dart';

class ItemDetailPage extends StatefulWidget {
  const ItemDetailPage({
    super.key,
    required this.item,
    this.options,
    this.onChanged,
  });
  final ClothingItem item;
  final ItemOptions? options;
  final VoidCallback? onChanged;

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  late ClothingItem _item = widget.item;
  bool _deleting = false;

  Future<void> _delete() async {
    if (_deleting) return;
    final delete = widget.options?.deleteItem;
    if (delete == null) return;
    setState(() => _deleting = true);
    try {
      await delete(_item.id);
      if (!mounted) return;
      widget.onChanged?.call();
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('删除失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<ClothingItem>(
      MaterialPageRoute(
        builder: (_) => EditItemPage(
          imagePath: _item.image,
          item: _item,
          options: widget.options,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _item = updated);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final attributes = <(String, String?)>[
      ('品类', _item.category.name),
      ('品牌', _item.brand?.name),
      ('尺寸', _item.size),
      (
        '颜色',
        [
          if (_item.primaryColor case final color?) color.name,
          ..._item.secondaryColors.map((color) => color.name),
        ].join('、'),
      ),
    ].where((entry) => entry.$2?.trim().isNotEmpty ?? false).toList();
    return PopScope(
      canPop: !_deleting,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: _deleting ? null : () => Navigator.pop(context),
          ),
          title: const Text('单品详情'),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: '删除单品',
              onPressed: _deleting || widget.options?.deleteItem == null
                  ? null
                  : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(
              tooltip: '编辑单品',
              onPressed: _deleting || widget.options?.updateItem == null
                  ? null
                  : _edit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  ItemImagePreview(imagePath: _item.image),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final entry in attributes)
                            SizedBox(
                              width: attributes.length == 1
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 12) / 2,
                              child: _Attribute(
                                name: entry.$1,
                                value: entry.$2!,
                              ),
                            ),
                          if (_item.note case final note?
                              when note.trim().isNotEmpty)
                            SizedBox(
                              width: constraints.maxWidth,
                              child: _Attribute(name: '备注', value: note),
                            ),
                        ],
                      ),
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
}

class _Attribute extends StatelessWidget {
  const _Attribute({required this.name, required this.value});
  final String name;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F3ED),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$name：'),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}
