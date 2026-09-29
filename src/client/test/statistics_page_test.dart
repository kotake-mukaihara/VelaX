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
    // Tap the center of the single category slice rather than its legend.
    final chart = find
        .byWidgetPredicate(
          (widget) => widget is GestureDetector && widget.onTapUp != null,
        )
        .first;
    expect(chart, findsOneWidget);
    await tester.tap(chart);
    await tester.pumpAndSettle();
    expect(find.text('衬衫'), findsOneWidget);
    expect(find.text('上装'), findsNothing);
    await tester.tap(find.byTooltip('返回一级品类'));
    await tester.pumpAndSettle();
    expect(find.text('上装'), findsOneWidget);
    expect(find.text('衬衫'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
