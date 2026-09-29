import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velax/domain/models/category.dart';
import 'package:velax/domain/models/clothing_item.dart';
import 'package:velax/features/statistics/statistics_page.dart';

void main() {
  final now = DateTime(2026);
  Category category(String id, String name, [String? parent]) => Category(
    id: id,
    name: name,
    parentId: parent,
    isPreset: true,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
  testWidgets(
    'ring starts at right and selects counterclockwise, excluding gaps',
    (tester) async {
      final first = category('a', '第一类');
      final second = category('b', '第二类');
      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsPage(
            loadCategories: () async => [first, second],
            loadItems: () async => [
              for (final c in [first, second])
                ClothingItem(
                  id: c.id,
                  image: '',
                  category: c,
                  createdAt: now,
                  updatedAt: now,
                ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chart = find
          .byWidgetPredicate((w) => w is GestureDetector && w.onTapUp != null)
          .first;
      final center = tester.getCenter(chart);
      final radius = tester.getSize(chart).width * .4;
      // The 3px gap excludes the same perpendicular distance at both edges.
      final innerPoint = tester.getSize(chart).width * .22;
      for (final distance in [innerPoint, radius]) {
        await tester.tapAt(center + Offset(distance, 1));
        await tester.pumpAndSettle();
        expect(find.byTooltip('返回一级品类'), findsNothing);
        await tester.tapAt(center + Offset(distance, -2));
        await tester.pumpAndSettle();
        expect(find.text('衣物品类占比 · 第一类'), findsOneWidget);
        await tester.tap(find.byTooltip('返回一级品类'));
        await tester.pumpAndSettle();
      }
      // The thicker ring now includes this point near the smaller hole.
      await tester.tapAt(center + Offset(0, -innerPoint));
      await tester.pumpAndSettle();
      expect(find.text('衣物品类占比 · 第一类'), findsOneWidget);
      await tester.tap(find.byTooltip('返回一级品类'));
      await tester.pumpAndSettle();
      await tester.tapAt(center + Offset(0, radius));
      await tester.pumpAndSettle();
      expect(find.text('衣物品类占比 · 第二类'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('category pie drills down and restores parent legend', (
    tester,
  ) async {
    final root = category('top', '上装');
    final child = category('shirt', '衬衫', 'top');
    final empty = category('shoes', '鞋履');
    await tester.pumpWidget(
      MaterialApp(
        home: StatisticsPage(
          loadItems: () async => [
            ClothingItem(
              id: '1',
              image: '',
              category: child,
              createdAt: now,
              updatedAt: now,
            ),
          ],
          loadCategories: () async => [root, child, empty],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('上装'), findsOneWidget);
    expect(find.text('鞋履'), findsNothing);
    // The hole is not interactive; the ring still drills down.
    final chart = find
        .byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.onTapUp != null,
        )
        .first;
    expect(chart, findsOneWidget);
    final chartTop = tester.getTopLeft(chart).dy;
    final legendTop = tester.getTopLeft(find.text('上装')).dy;
    await tester.tap(chart);
    await tester.pumpAndSettle();
    expect(find.text('上装'), findsOneWidget);
    expect(find.text('衬衫'), findsNothing);
    await tester.tapAt(
      tester.getCenter(chart) + Offset(tester.getSize(chart).width * .4, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('衬衫'), findsOneWidget);
    expect(find.text('上装'), findsNothing);
    final drilledChart = find
        .byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.child is CustomPaint,
        )
        .first;
    expect(tester.getTopLeft(drilledChart).dy, chartTop);
    expect(tester.getTopLeft(find.text('衬衫')).dy, legendTop);
    await tester.tap(find.byTooltip('返回一级品类'));
    await tester.pumpAndSettle();
    expect(find.text('上装'), findsOneWidget);
    expect(find.text('衬衫'), findsNothing);
    expect(tester.getTopLeft(chart).dy, chartTop);
    expect(tester.getTopLeft(find.text('上装')).dy, legendTop);
    expect(tester.takeException(), isNull);
  });
}
