import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velax/domain/models/category.dart';
import 'package:velax/domain/models/clothing_item.dart';
import 'package:velax/features/home/home_page.dart';
import 'package:velax/features/wardrobe/wardrobe_page.dart';

void main() {
  for (final home in [true, false]) {
    testWidgets(
      '${home ? 'recent additions' : 'wardrobe rows'} mouse scrolling',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final date = DateTime.utc(2026);
        final category = Category(
          id: 'shirts',
          name: '衬衫',
          isPreset: false,
          sortOrder: 0,
          createdAt: date,
          updatedAt: date,
        );
        final items = List.generate(
          5,
          (i) => ClothingItem(
            id: '$i',
            image: '/missing-$i.jpg',
            category: category,
            createdAt: date,
            updatedAt: date,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: home
                  ? HomePage(loadItems: () async => items)
                  : WardrobePage(
                      loadItems: () async => items,
                      loadCategories: () async => [category],
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final strip = find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.horizontal,
        );
        await tester.ensureVisible(strip);
        await tester.pumpAndSettle();
        final state = tester.state<ScrollableState>(
          find.descendant(of: strip, matching: find.byType(Scrollable)),
        );
        expect(state.position.pixels, 0);
        await tester.drag(
          strip,
          const Offset(-500, 0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(state.position.pixels, greaterThan(0));
        await tester.drag(
          strip,
          const Offset(500, 0),
          kind: PointerDeviceKind.mouse,
        );
        await tester.pumpAndSettle();
        expect(state.position.pixels, 0);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.windows,
        TargetPlatform.macOS,
      }),
    );
  }
}
