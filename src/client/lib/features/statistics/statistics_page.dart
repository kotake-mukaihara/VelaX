import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/category.dart';
import '../../domain/models/clothing_item.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({
    super.key,
    required this.loadItems,
    this.loadCategories,
  });

  final Future<List<ClothingItem>> Function() loadItems;
  final Future<List<Category>> Function()? loadCategories;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late Future<(List<ClothingItem>, List<Category>)> _data = _load();
  Category? _selectedCategory;

  Future<(List<ClothingItem>, List<Category>)> _load() async {
    final items = await widget.loadItems();
    final categories = await widget.loadCategories?.call() ?? <Category>[];
    return (items, categories);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('数据统计'),
      leading: BackButton(onPressed: () => Navigator.pop(context)),
    ),
    body: FutureBuilder<(List<ClothingItem>, List<Category>)>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('数据加载失败，请重试'),
                TextButton(
                  onPressed: () => setState(() => _data = _load()),
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }
        final (items, categories) = snapshot.data!;
        final byId = {for (final c in categories) c.id: c};
        for (final item in items) {
          byId.putIfAbsent(item.category.id, () => item.category);
        }
        final categoryCounts = <String, int>{};
        for (final item in items) {
          final c = item.category;
          if (_selectedCategory != null &&
              (c.parentId ?? c.id) != _selectedCategory!.id) {
            continue;
          }
          final id = _selectedCategory == null ? c.parentId ?? c.id : c.id;
          categoryCounts.update(id, (v) => v + 1, ifAbsent: () => 1);
        }
        final ids = categoryCounts.keys.toList()
          ..sort((a, b) {
            final order = (byId[a]?.sortOrder ?? 0).compareTo(
              byId[b]?.sortOrder ?? 0,
            );
            return order == 0 ? a.compareTo(b) : order;
          });
        final categorySlices = [
          for (var i = 0; i < ids.length; i++)
            _Slice(
              ids[i],
              byId[ids[i]]?.name ?? '未知品类',
              categoryCounts[ids[i]]!,
              _palette[i % _palette.length],
            ),
        ];
        final colors = <String, _Slice>{};
        final brands = <String?, (String, int)>{null: ('未知', 0)};
        for (final item in items) {
          final color = item.primaryColor;
          final id = color?.id ?? '';
          final previous = colors[id];
          colors[id] = _Slice(
            id,
            color?.name ?? '未知',
            (previous?.count ?? 0) + 1,
            color == null
                ? const Color(0xFF9E9E9E)
                : Color(
                    0xFF000000 |
                        int.parse(color.hex.replaceFirst('#', ''), radix: 16),
                  ),
          );
          final brand = item.brand;
          brands[brand?.id] = (
            brand?.name ?? '未知',
            (brands[brand?.id]?.$2 ?? 0) + 1,
          );
        }
        final scheme = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 22,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      '风格画像',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _chartCard(
                  context,
                  title: _selectedCategory == null
                      ? '衣物品类占比'
                      : '衣物品类占比 · ${_selectedCategory!.name}',
                  action: _selectedCategory == null
                      ? null
                      : IconButton(
                          tooltip: '返回一级品类',
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () =>
                              setState(() => _selectedCategory = null),
                        ),
                  child: _PieChart(
                    slices: categorySlices,
                    onSelect: _selectedCategory != null
                        ? null
                        : (slice) {
                            final category = byId[slice.id];
                            if (category != null) {
                              setState(() => _selectedCategory = category);
                            }
                          },
                  ),
                ),
                const SizedBox(height: 20),
                _chartCard(
                  context,
                  title: '主色占比',
                  child: _PieChart(slices: colors.values.toList()),
                ),
                const SizedBox(height: 20),
                _chartCard(
                  context,
                  title: '品牌分布',
                  child: items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: Text('暂无衣物数据')),
                        )
                      : Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final brand in brands.values)
                              Container(
                                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(child: Text(brand.$1)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.secondaryContainer,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text('${brand.$2}'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _chartCard(
    BuildContext context, {
    required String title,
    required Widget child,
    Widget? action,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

const _palette = [
  Color(0xFF668C82),
  Color(0xFFDBA66D),
  Color(0xFF7B91BE),
  Color(0xFFBD8093),
  Color(0xFF9B8AB8),
  Color(0xFFB2AE72),
  Color(0xFF66AAB1),
  Color(0xFFC7816E),
];

class _Slice {
  const _Slice(this.id, this.name, this.count, this.color);
  final String id;
  final String name;
  final int count;
  final Color color;
}

class _PieChart extends StatelessWidget {
  const _PieChart({required this.slices, this.onSelect});
  final List<_Slice> slices;
  final ValueChanged<_Slice>? onSelect;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: Text('暂无衣物数据')),
      );
    }
    final total = slices.fold(0, (sum, slice) => sum + slice.count);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = math.min(constraints.maxWidth, 240.0);
              return Center(
                child: SizedBox(
                  width: size,
                  height: size,
                  child: GestureDetector(
                    onTapUp: onSelect == null
                        ? null
                        : (details) {
                            final offset =
                                details.localPosition -
                                Offset(size / 2, size / 2);
                            if (offset.distance > size / 2) return;
                            final angle =
                                (math.atan2(offset.dy, offset.dx) +
                                    math.pi / 2) %
                                (2 * math.pi);
                            var end = 0.0;
                            for (final slice in slices) {
                              end += slice.count / total * math.pi * 2;
                              if (angle < end) {
                                onSelect!(slice);
                                return;
                              }
                            }
                          },
                    child: CustomPaint(painter: _PiePainter(slices, total)),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final slice in slices)
                Semantics(
                  button: onSelect != null,
                  label:
                      '${slice.name}，${slice.count}件，占比${(slice.count / total * 100).toStringAsFixed(1)}%',
                  child: InkWell(
                    onTap: onSelect == null ? null : () => onSelect!(slice),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: slice.color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(slice.name)),
                          const SizedBox(width: 6),
                          Text('${slice.count}'),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.slices, this.total);
  final List<_Slice> slices;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = slice.count / total * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        true,
        Paint()..color = slice.color,
      );
      final percent = slice.count / total * 100;
      final text = TextPainter(
        text: TextSpan(
          text:
              '${percent.toStringAsFixed(percent == percent.roundToDouble() ? 0 : 1)}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: slice.color.computeLuminance() > .4
                ? Colors.black
                : Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final position = slices.length == 1
          ? center
          : center +
                Offset(
                      math.cos(start + sweep / 2),
                      math.sin(start + sweep / 2),
                    ) *
                    (radius * .68);
      text.paint(canvas, position - Offset(text.width / 2, text.height / 2));
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) => oldDelegate.slices != slices;
}
