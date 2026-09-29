import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/clothing_item.dart';
import '../../domain/models/color.dart' as model;
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除单品？'),
          content: const Text('删除后数据不可恢复，确定要删除这个单品吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认删除'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
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
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final entry in attributes)
                            SizedBox(
                              width: (constraints.maxWidth - 12) / 2,
                              child: _Attribute(
                                name: entry.$1,
                                value: entry.$2!,
                              ),
                            ),
                          SizedBox(
                            width: (constraints.maxWidth - 12) / 2,
                            child: _Attribute(
                              name: '颜色',
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.end,
                                children: [
                                  _ColorBall(
                                    color: _item.primaryColor,
                                    size: 24,
                                  ),
                                  for (final color in _item.secondaryColors)
                                    _ColorBall(color: color, size: 16),
                                ],
                              ),
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
  const _Attribute({required this.name, this.value, this.child});
  final String name;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child != null
        ? Row(
            children: [
              Text('$name：'),
              Expanded(child: child!),
            ],
          )
        : Text.rich(
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

class _ColorBall extends StatelessWidget {
  const _ColorBall({required this.color, required this.size});

  final model.Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: color == null ? const _DashedCirclePainter() : null,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color == null
            ? Colors.white
            : Color(int.parse(color!.hex.replaceFirst('#', 'FF'), radix: 16)),
        border: color == null ? null : Border.all(color: Colors.black12),
      ),
    ),
  );
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final bounds = (Offset.zero & size).deflate(0.5);
    for (var i = 0; i < 12; i++) {
      canvas.drawArc(bounds, i * math.pi / 6, math.pi / 10, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) => false;
}
