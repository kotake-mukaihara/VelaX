import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velax/domain/models/category.dart';
import 'package:velax/domain/models/clothing_item.dart';
import 'package:velax/features/home/home_page.dart';
import 'package:velax/features/wardrobe/item_detail_page.dart';
import 'package:velax/features/wardrobe/item_options.dart';

void main() {
  final now = DateTime.utc(2026);
  final category = Category(
    id: 'top',
    name: '上装',
    isPreset: true,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  );
  ClothingItem item() => ClothingItem(
    id: 'one',
    image: '/missing.jpg',
    category: category,
    size: 'M',
    note: '原备注',
    createdAt: now,
    updatedAt: now,
  );
  String content(Widget widget) =>
      widget is Text ? widget.data ?? widget.textSpan?.toPlainText() ?? '' : '';

  testWidgets(
    'detail hides unset attributes and uses two columns with full width note',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: ItemDetailPage(item: item())));
      await tester.pumpAndSettle();
      final type = find.byWidgetPredicate((w) => content(w) == '品类：上装');
      final size = find.byWidgetPredicate((w) => content(w) == '尺寸：M');
      final note = find.byWidgetPredicate((w) => content(w) == '备注：原备注');
      expect(type, findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => content(w).startsWith('品牌：')),
        findsNothing,
      );
      expect(
        find.byWidgetPredicate((w) => content(w).startsWith('颜色：')),
        findsNothing,
      );
      expect(tester.getTopLeft(type).dy, tester.getTopLeft(size).dy);
      expect(
        tester.getSize(note).width,
        greaterThan(tester.getSize(type).width),
      );
      final span = tester.widget<Text>(type).textSpan! as TextSpan;
      expect(span.children!.last.style!.fontWeight, FontWeight.bold);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'open from home, edit existing item, refresh wardrobe, delete and refresh home',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var items = [item()];
      var updates = 0;
      final options = ItemOptions(
        categories: () async => [category],
        brands: () async => [],
        colors: () async => [],
        createBrand: (_) async => throw UnimplementedError(),
        saveItem: (_, _, _, _, _, _) async =>
            fail('Editing must not create an item'),
        updateItem: (updated) async {
          expect(updated.id, 'one');
          expect(updated.createdAt, now);
          updates++;
          items = [updated];
          return updated;
        },
        deleteItem: (id) async => items.removeWhere((item) => item.id == id),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomePage(
            loadItems: () async => items,
            loadCategories: () async => [category],
            itemOptions: options,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Image).first);
      await tester.pumpAndSettle();
      expect(find.text('单品详情'), findsOneWidget);
      await tester.tap(find.byTooltip('编辑单品'));
      await tester.pumpAndSettle();
      expect(find.text('编辑单品'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '原备注',
      );
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '新备注');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(updates, 1);
      expect(
        find.byWidgetPredicate((w) => content(w) == '备注：新备注'),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('衣橱').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wardrobe-photo-one')));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => content(w) == '备注：新备注'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('删除单品'));
      await tester.pumpAndSettle();
      expect(items, isEmpty);
      expect(find.text('单品详情'), findsNothing);
      expect(find.text('还没有衣物'), findsOneWidget);
      await tester.tap(find.text('首页').last);
      await tester.pumpAndSettle();
      expect(find.text('还没有衣物'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed deletion retains detail and allows retry', (
    tester,
  ) async {
    var attempts = 0;
    final options = ItemOptions(
      categories: () async => [],
      brands: () async => [],
      colors: () async => [],
      createBrand: (_) async => throw UnimplementedError(),
      deleteItem: (_) async {
        attempts++;
        throw StateError('offline');
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ItemDetailPage(item: item(), options: options),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除单品'));
    await tester.pumpAndSettle();
    expect(find.text('删除失败，请重试'), findsOneWidget);
    expect(find.text('单品详情'), findsOneWidget);
    await tester.tap(find.byTooltip('删除单品'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
}
