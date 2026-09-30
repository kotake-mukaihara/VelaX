import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velax/domain/models/brand.dart';
import 'package:velax/domain/models/category.dart';
import 'package:velax/domain/models/color.dart' as model;
import 'package:velax/features/wardrobe/edit_image_page.dart';
import 'package:velax/features/wardrobe/crop_image_page.dart';
import 'package:velax/features/wardrobe/item_options.dart';

void main() {
  late Directory directory;
  late File source;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('velax_item_edit_');
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 20, 20), Paint()..color = Colors.red);
    final picture = recorder.endRecording();
    final image = await picture.toImage(20, 20);
    picture.dispose();
    source = File('${directory.path}/source.png');
    await source.writeAsBytes(
      (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
          .asUint8List(),
    );
    image.dispose();
  });
  tearDownAll(() async {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await source.delete();
    await directory.delete();
  });
  testWidgets(
    'selection sheets confirm, cancel and restore the draft after back',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.utc(2026);
      var saved = false;
      final options = ItemOptions(
        saveItem: (image, category, brand, size, colors, note) async {
          expect(category.id, 'shirt');
          expect(brand?.name, 'New Brand');
          expect(size, 'M');
          expect(colors.first?.id, 'red');
          expect(note, '春季穿搭');
          saved = true;
        },
        categories: () async => [
          Category(
            id: 'top',
            name: '上装',
            isPreset: true,
            sortOrder: 0,
            createdAt: now,
            updatedAt: now,
          ),
          Category(
            id: 'shirt',
            name: '衬衫',
            parentId: 'top',
            isPreset: true,
            sortOrder: 1,
            createdAt: now,
            updatedAt: now,
          ),
        ],
        brands: () async => [
          Brand(id: 'old', name: 'Old Brand', createdAt: now, updatedAt: now),
        ],
        createBrand: (name) async => Brand(
          id: 'new',
          name: name,
          createdAt: now.add(const Duration(days: 1)),
          updatedAt: now,
        ),
        colors: () async => [
          const model.Color(id: 'red', name: '红色', hex: '#FF0000'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EditImagePage(imagePath: source.path, options: options),
        ),
      );
      for (
        var i = 0;
        i < 100 &&
            find.byKey(const ValueKey('crop-preview')).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(
        tester.widget<CropImagePage>(find.byType(CropImagePage)).session!.image,
        isNotNull,
      );
      await tester.pumpAndSettle();
      Future<void> tap(String text) async {
        await tester.ensureVisible(find.text(text).last);
        await tester.tap(find.text(text).last);
        await tester.pumpAndSettle();
      }

      await tap('下一步');
      expect(find.text('未设置'), findsNWidgets(4));
      await tap('品类');
      await tap('衬衫');
      await tap('确认');
      expect(find.text('衬衫'), findsOneWidget);
      await tap('品牌');
      await tester.enterText(find.byType(TextField).last, 'New Brand');
      await tester.pumpAndSettle();
      await tap('添加');
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
      );
      expect(find.text('Old Brand'), findsOneWidget);
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'New Brand'))
            .selected,
        isTrue,
      );
      await tap('确认');
      await tap('尺寸');
      await tap('M');
      await tap('确认');
      await tap('尺寸');
      await tap('XL');
      await tap('取消');
      expect(find.text('M'), findsOneWidget);
      await tap('颜色');
      expect(find.text('请先选择要编辑的项目'), findsOneWidget);
      expect(
        tester.widget<FilterChip>(find.byType(FilterChip)).onSelected,
        isNull,
      );
      await tap('主色');
      await tester.tap(find.widgetWithText(FilterChip, '红色'));
      await tester.pumpAndSettle();
      await tap('确认');
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '春季穿搭');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('编辑图片'), findsOneWidget);
      await tap('下一步');
      for (final value in ['衬衫', 'New Brand', 'M', '红色', '春季穿搭']) {
        expect(find.text(value), findsOneWidget);
      }
      expect(find.text('保存').hitTestable(), findsOneWidget);
      await tap('保存');
      expect(saved, isTrue);
      expect(find.text('编辑单品'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
