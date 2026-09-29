import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velax/domain/models/category.dart';
import 'package:velax/domain/models/clothing_item.dart';
import 'package:velax/features/wardrobe/wardrobe_page.dart';

void main() {
  final date = DateTime.utc(2026);
  Category category(String id, String name, {String? parent}) => Category(
    id: id,
    name: name,
    parentId: parent,
    isPreset: false,
    sortOrder: 0,
    createdAt: date,
    updatedAt: date,
  );

  testWidgets('groups, counts, sorts and scrolls all photos', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final root = category('custom', '自定义上装');
    final child = category('shirts', '衬衫', parent: root.id);
    final empty = category('empty', '空品类');
    final items = List.generate(
      8,
      (i) => ClothingItem(
        id: '$i',
        image: '/missing-$i.jpg',
        category: child,
        createdAt: date.add(Duration(days: i)),
        updatedAt: date,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WardrobePage(
            loadItems: () async => items,
            loadCategories: () async => [root, child, empty],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('自定义上装'), findsOneWidget);
    expect(find.text('衬衫'), findsOneWidget);
    expect(find.text('8'), findsNWidgets(2));
    expect(find.text('空品类'), findsNothing);
    for (final label in ['筛选', '分类', '更多']) {
      expect(find.byTooltip(label), findsNothing);
    }
    final newest = find.byKey(const ValueKey('wardrobe-photo-7'));
    final next = find.byKey(const ValueKey('wardrobe-photo-6'));
    expect(tester.getTopLeft(newest).dx, lessThan(tester.getTopLeft(next).dx));
    final strip = find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.horizontal,
    );
    await tester.drag(strip, const Offset(-1500, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wardrobe-photo-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed load can be retried', (tester) async {
    var fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WardrobePage(
            loadItems: () async {
              if (fail) throw StateError('load failed');
              return [];
            },
            loadCategories: () async => [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('衣橱加载失败，请重试'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();
    expect(find.text('还没有衣物'), findsOneWidget);
  });
}
