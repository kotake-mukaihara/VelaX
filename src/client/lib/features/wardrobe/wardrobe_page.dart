import 'dart:io';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import '../../domain/models/category.dart';
import '../../domain/models/clothing_item.dart';

class WardrobePage extends StatefulWidget {
  const WardrobePage({
    super.key,
    required this.loadItems,
    required this.loadCategories,
    this.wide = false,
    this.onOpenItem,
  });

  final Future<List<ClothingItem>> Function() loadItems;
  final Future<List<Category>> Function() loadCategories;
  final bool wide;
  final ValueChanged<ClothingItem>? onOpenItem;

  @override
  State<WardrobePage> createState() => _WardrobePageState();
}

class _WardrobePageState extends State<WardrobePage> {
  late Future<(List<ClothingItem>, List<Category>)> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<(List<ClothingItem>, List<Category>)> _load() async {
    final items = await widget.loadItems();
    final categories = await widget.loadCategories();
    return (items, categories);
  }

  Future<void> _refresh() async {
    final request = _load();
    setState(() {
      _data = request;
    });
    try {
      await request;
    } catch (_) {
      // The FutureBuilder displays the error and retry action.
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(widget.wide ? 40 : 24, 20, 12, 16),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                '我的衣橱',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            for (final action in [
              ('筛选', Icons.filter_alt_outlined),
              ('分类', Icons.category_outlined),
              ('更多', Icons.more_horiz),
            ])
              IconButton(
                tooltip: action.$1,
                onPressed: null,
                icon: Icon(action.$2),
              ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<(List<ClothingItem>, List<Category>)>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = [...?snapshot.data?.$1]
              ..sort((a, b) {
                final order = b.createdAt.compareTo(a.createdAt);
                return order == 0 ? a.id.compareTo(b.id) : order;
              });
            final categories = {
              for (final item in items) item.category.id: item.category,
              for (final category in snapshot.data?.$2 ?? <Category>[])
                category.id: category,
            };
            final roots = <String, Map<String, List<ClothingItem>>>{};
            for (final item in items) {
              final root = item.category.parentId ?? item.category.id;
              roots
                  .putIfAbsent(root, () => {})
                  .putIfAbsent(item.category.id, () => [])
                  .add(item);
            }
            int compareCategories(String a, String b) {
              final order = (categories[a]?.sortOrder ?? 0).compareTo(
                categories[b]?.sortOrder ?? 0,
              );
              return order == 0 ? a.compareTo(b) : order;
            }

            final rootIds = roots.keys.toList()..sort(compareCategories);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  widget.wide ? 40 : 24,
                  8,
                  widget.wide ? 40 : 24,
                  96,
                ),
                itemCount: snapshot.hasError || items.isEmpty
                    ? 1
                    : rootIds.length,
                itemBuilder: (context, index) {
                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        const Text('衣橱加载失败，请重试'),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('重试'),
                        ),
                      ],
                    );
                  }
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 64),
                      child: Column(
                        children: [
                          Icon(
                            Icons.checkroom_outlined,
                            size: 40,
                            color: Color(0xFF87917F),
                          ),
                          SizedBox(height: 16),
                          Text('还没有衣物'),
                          SizedBox(height: 8),
                          Text(
                            '添加后，衣物会按品类展示在这里',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    );
                  }
                  final root = rootIds[index];
                  final groups = roots[root]!;
                  final children = groups.keys.toList()
                    ..sort(compareCategories);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _CategoryHeading(
                          name: categories[root]?.name ?? '未命名品类',
                          count: groups.values.fold(
                            0,
                            (n, list) => n + list.length,
                          ),
                          primary: true,
                        ),
                        for (final child in children) ...[
                          const SizedBox(height: 20),
                          _CategoryHeading(
                            name: child == root
                                ? '未细分'
                                : categories[child]!.name,
                            count: groups[child]!.length,
                          ),
                          const SizedBox(height: 12),
                          _PhotoStrip(
                            items: groups[child]!,
                            onOpenItem: widget.onOpenItem,
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}

class _CategoryHeading extends StatelessWidget {
  const _CategoryHeading({
    required this.name,
    required this.count,
    this.primary = false,
  });
  final String name;
  final int count;
  final bool primary;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(
        child: Text(
          name,
          style: TextStyle(
            fontSize: primary ? 22 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        '$count',
        style: TextStyle(
          fontSize: primary ? 18 : 14,
          color: const Color(0xFF72796B),
        ),
      ),
    ],
  );
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.items, this.onOpenItem});
  final List<ClothingItem> items;
  final ValueChanged<ClothingItem>? onOpenItem;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 164,
    child: ScrollConfiguration(
      behavior: ScrollConfiguration.of(context)
          .copyWith(dragDevices: {...PointerDeviceKind.values}),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => Semantics(
          label: '${items[index].category.name}，第${index + 1}件',
          image: true,
          child: InkWell(
            onTap: onOpenItem == null ? null : () => onOpenItem!(items[index]),
            child: ClipRRect(
              key: ValueKey('wardrobe-photo-${items[index].id}'),
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(items[index].image),
                width: 132,
                height: 164,
                fit: BoxFit.cover,
                cacheWidth: 400,
                errorBuilder: (_, _, _) => Container(
                  width: 132,
                  color: const Color(0xFFEDEEE8),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      semanticLabel: '照片无法读取',
                      color: Colors.black38,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
