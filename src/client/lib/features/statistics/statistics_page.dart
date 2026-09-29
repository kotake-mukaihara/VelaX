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
  // Keep chart colors independent of the UI theme and stable during drill-down.
  final List<Color> _categoryPalette = [..._palette]..shuffle(math.Random());
  final Map<String, Color> _categoryColors = {};

  Color _categoryColor(String id) => _categoryColors.putIfAbsent(
    id,
    () => _categoryPalette[_categoryColors.length % _categoryPalette.length],
  );

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
              _categoryColor(ids[i]),
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
                ? Colors.white
                : Color(
                    0xFF000000 |
                        int.parse(color.hex.replaceFirst('#', ''), radix: 16),
                  ),
            dashedOutline: color == null,
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
                          iconSize: 20,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
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
                            for (final brand in brands.values.where(
                              (brand) => brand.$2 > 0,
                            ))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        brand.$1,
                                        style: TextStyle(
                                          color: scheme.onSecondaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${brand.$2}',
                                      style: TextStyle(
                                        color: scheme.onSecondaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
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
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          // Reserve the action's height before drilling into a category.
          height: math.max(
            32,
            MediaQuery.textScalerOf(context).scale(17) * 1.5,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?action,
            ],
          ),
        ),
        const SizedBox(height: 12),
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
  const _Slice(
    this.id,
    this.name,
    this.count,
    this.color, {
    this.dashedOutline = false,
  });
  final String id;
  final String name;
  final int count;
  final Color color;
  final bool dashedOutline;
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
                            var start = 0.0;
                            for (final slice in slices) {
                              final sweep = slice.count / total * math.pi * 2;
                              if (_ringSlicePath(
                                size / 2,
                                start,
                                sweep,
                                slices.length,
                              ).contains(offset)) {
                                onSelect!(slice);
                                return;
                              }
                              start -= sweep;
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

const _innerRadiusRatio = .38;
const _segmentGapWidth = 3.0;

// Subtract parallel-sided strips, rather than angular wedges, so the gap
// has the same physical width at both the inner and outer edges.
Path _ringSlicePath(double radius, double start, double sweep, int count) {
  final outer = Rect.fromCircle(center: Offset.zero, radius: radius);
  final sector = count == 1
      ? (Path()..addOval(outer))
      : (Path()
          ..moveTo(0, 0)
          ..arcTo(outer, start, -sweep, false)
          ..close());
  final hole = Path()
    ..addOval(
      Rect.fromCircle(center: Offset.zero, radius: radius * _innerRadiusRatio),
    );
  var ring = Path.combine(PathOperation.difference, sector, hole);
  if (count > 1) {
    for (final angle in [start, start - sweep]) {
      final direction = Offset(math.cos(angle), math.sin(angle));
      final normal =
          Offset(-direction.dy, direction.dx) * (_segmentGapWidth / 2);
      final end = direction * (radius + _segmentGapWidth);
      final strip = Path()
        ..addPolygon([normal, end + normal, end - normal, -normal], true);
      ring = Path.combine(PathOperation.difference, ring, strip);
    }
  }
  return ring;
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.slices, this.total);
  final List<_Slice> slices;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final innerRadius = radius * _innerRadiusRatio;
    final strokeWidth = radius - innerRadius;
    final ringRadius = (radius + innerRadius) / 2;
    var start = 0.0;
    for (final slice in slices) {
      final sweep = slice.count / total * math.pi * 2;
      final path = _ringSlicePath(
        radius,
        start,
        sweep,
        slices.length,
      ).shift(center);
      canvas.drawPath(path, Paint()..color = slice.color);
      if (slice.dashedOutline) {
        final outline = Path();
        for (final metric in path.computeMetrics()) {
          for (var distance = 0.0; distance < metric.length; distance += 7) {
            outline.addPath(
              metric.extractPath(
                distance,
                math.min(distance + 4, metric.length),
              ),
              Offset.zero,
            );
          }
        }
        // Keep the outline inside the segment and preserve the chart gaps.
        canvas.save();
        canvas.clipPath(path);
        canvas.drawPath(
          outline,
          Paint()
            ..color = Colors.grey
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        canvas.restore();
      }
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
      final visible = math.max(
        0.0,
        sweep - (slices.length > 1 ? _segmentGapWidth / ringRadius : 0),
      );
      final middle = start - sweep / 2;
      final position =
          center + Offset(math.cos(middle), math.sin(middle)) * ringRadius;
      // Small segments remain readable through the legend and semantics.
      if (visible * ringRadius > text.width + 8 &&
          strokeWidth > text.height + 4) {
        text.paint(canvas, position - Offset(text.width / 2, text.height / 2));
      }
      text.dispose();
      start -= sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) => oldDelegate.slices != slices;
}
