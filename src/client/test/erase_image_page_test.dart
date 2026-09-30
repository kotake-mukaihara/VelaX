import 'package:velax/features/wardrobe/crop_image_page.dart';
import 'package:velax/features/wardrobe/edit_image_page.dart';

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velax/features/wardrobe/erase_image_page.dart';
import 'package:velax/features/wardrobe/erase_image_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File source;
  late ui.Image image;

  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('velax_erase_test_');
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 200, 200),
      Paint()..color = Colors.red,
    );
    final picture = recorder.endRecording();
    image = await picture.toImage(200, 200);
    picture.dispose();
    source = File('${directory.path}/source.png');
    await source.writeAsBytes(
      (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
          .asUint8List(),
    );
  });
  tearDownAll(() async {
    image.dispose();
    await source.delete();
    await directory.delete();
  });

  test(
    'PNG clears selected pixels, keeps dimensions and surrounding pixels',
    () async {
      final bytes = await renderErasedImage(image, [
        EraseStroke([const Offset(80, 100), const Offset(120, 100)], 20),
      ]);
      final codec = await ui.instantiateImageCodec(bytes);
      final result = (await codec.getNextFrame()).image;
      expect(result.width, 200);
      expect(result.height, 200);
      final pixels = (await result.toByteData())!.buffer.asUint8List();
      expect(pixels[(100 * 200 + 100) * 4 + 3], 0);
      expect(pixels[(20 * 200 + 20) * 4 + 3], 255);
      result.dispose();
      codec.dispose();
    },
  );

  test(
    'erased edge updates output bounds and empty images stay valid',
    () async {
      final strokes = [
        EraseStroke([const Offset(0, -100), const Offset(0, 300)], 100),
      ];
      final bounds = await erasedContentBounds(image, strokes);
      expect(bounds, const Rect.fromLTRB(50, 0, 200, 200));
      final codec = await ui.instantiateImageCodec(
        await renderErasedImage(image, strokes, bounds: bounds),
      );
      final result = (await codec.getNextFrame()).image;
      expect(result.width, 150);
      expect(result.height, 200);
      result.dispose();
      codec.dispose();
      expect(
        await erasedContentBounds(image, [
          EraseStroke([const Offset(100, 100)], 1000),
        ]),
        const Rect.fromLTWH(0, 0, 200, 200),
      );
    },
  );
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: EraseImagePage(imagePath: source.path)),
    );
    for (
      var i = 0;
      i < 100 && find.byKey(const ValueKey('erase-preview')).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('erase-preview')), findsOneWidget);
  }

  bool enabled(WidgetTester tester) =>
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('erase-apply')))
          .onPressed !=
      null;

  testWidgets(
    'drawing waits for erase, undo restores selection, reset is undoable',
    (tester) async {
      await open(tester);
      expect(enabled(tester), isFalse);
      expect(find.text('重置'), findsNothing);
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('erase-brush')),
      );
      expect([slider.min, slider.max, slider.divisions], [20, 100, 8]);
      await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('erase-preview'))),
        const Offset(30, 0),
      );
      await tester.pump();
      expect(enabled(tester), isTrue);
      expect(find.text('重置'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('erase-apply')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(enabled(tester), isFalse);
      await tester.tap(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '撤销'),
      );
      await tester.pump();
      expect(enabled(tester), isTrue);
      await tester.tap(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '恢复'),
      );
      await tester.pump();
      expect(enabled(tester), isFalse);
      await tester.tap(find.text('重置'));
      await tester.pump();
      expect(find.text('重置'), findsNothing);
      await tester.tap(
        find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '撤销'),
      );
      await tester.pump();
      expect(find.text('重置'), findsOneWidget);
    },
  );

  testWidgets(
    'two fingers cancel the tentative stroke and never draw on release',
    (tester) async {
      await open(tester);
      final center = tester.getCenter(
        find.byKey(const ValueKey('erase-preview')),
      );
      final first = await tester.startGesture(
        center - const Offset(30, 0),
        pointer: 1,
      );
      await first.moveBy(const Offset(5, 0));
      final second = await tester.startGesture(
        center + const Offset(30, 0),
        pointer: 2,
      );
      await first.moveBy(const Offset(-20, 10));
      await second.moveBy(const Offset(20, 10));
      await second.up();
      await first.moveBy(const Offset(10, 0));
      await first.up();
      await tester.pump();
      expect(enabled(tester), isFalse);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == '撤销',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('重置'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'integrated editor defaults to crop and keeps erase action visible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: EditImagePage(imagePath: source.path)),
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
      expect(find.byKey(const ValueKey('crop-preview')), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const ValueKey('edit-image-next')))
            .onPressed,
        isNotNull,
      );
      expect(find.byTooltip('一键抠图'), findsNothing);
      await tester.tap(find.text('擦除'));
      for (
        var i = 0;
        i < 100 &&
            find.byKey(const ValueKey('erase-preview')).evaluate().isEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(find.byKey(const ValueKey('erase-apply')), findsOneWidget);
      expect(enabled(tester), isFalse);
      expect(find.byTooltip('一键抠图'), findsOneWidget);
      expect(
        tester.getCenter(find.byKey(const ValueKey('erase-apply'))).dy,
        lessThan(
          tester.getCenter(find.byKey(const ValueKey('erase-brush'))).dy,
        ),
      );
      await tester.dragFrom(
        tester.getCenter(find.byKey(const ValueKey('erase-preview'))),
        const Offset(30, 0),
      );
      await tester.pump();
      expect(enabled(tester), isTrue);
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('erase-apply')));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      expect(find.byKey(const ValueKey('erase-apply')), findsOneWidget);
      expect(enabled(tester), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'theme and persistent controls in $brightness; switching retains state',
      (tester) async {
        final theme = ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: brightness,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: EditImagePage(imagePath: source.path),
          ),
        );
        for (var i = 0; i < 100; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          if (find
                  .byKey(const ValueKey('crop-preview'), skipOffstage: false)
                  .evaluate()
                  .isNotEmpty &&
              find
                  .byKey(const ValueKey('erase-preview'), skipOffstage: false)
                  .evaluate()
                  .isNotEmpty) {
            break;
          }
        }
        await tester.pumpAndSettle();
        expect(
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
          theme.colorScheme.surface,
        );
        final crop = tester.state<CropImagePageState>(
          find.byType(CropImagePage),
        );
        final session = tester
            .widget<CropImagePage>(find.byType(CropImagePage))
            .session!;
        final original = session.image;
        expect(
          tester
              .widget<EraseImagePage>(
                find.byType(EraseImagePage, skipOffstage: false),
              )
              .session,
          same(session),
        );
        await tester.tap(find.byTooltip('逆时针旋转90°'));
        await tester.pumpAndSettle();
        final cropParameters = session.crop;
        await tester.tap(find.text('擦除'));
        // Switching an edited session needs no asynchronous rendering or I/O.
        await tester.pump();
        final erase = tester.state<EraseImagePageState>(
          find.byType(EraseImagePage),
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );
        for (final tooltip in ['撤销', '恢复']) {
          final button = tester.widget<IconButton>(
            find.byWidgetPredicate(
              (w) => w is IconButton && w.tooltip == tooltip,
            ),
          );
          expect(button.onPressed, isNull);
          expect(
            button.disabledColor,
            theme.colorScheme.onSurface.withValues(alpha: 0.45),
          );
        }
        expect(
          find.byKey(const ValueKey('erase-apply')).hitTestable(),
          findsOneWidget,
        );
        expect(enabled(tester), isFalse);
        expect(
          find.byKey(const ValueKey('erase-cutout')).hitTestable(),
          findsOneWidget,
        );
        await tester.dragFrom(
          tester.getCenter(find.byKey(const ValueKey('erase-preview'))),
          const Offset(30, 0),
        );
        await tester.pump();
        expect(enabled(tester), isTrue);
        await tester.tap(find.byKey(const ValueKey('erase-apply')));
        await tester.pump();
        expect(session.erase.erased, hasLength(1));
        expect(session.crop, same(cropParameters));
        await tester.tap(find.text('裁剪'));
        await tester.pump();
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          0,
        );
        await tester.tap(find.text('擦除'));
        await tester.pump();
        // Start a new pending stroke for the state-retention checks below.
        await tester.dragFrom(
          tester.getCenter(find.byKey(const ValueKey('erase-preview'))),
          const Offset(30, 0),
        );
        await tester.pump();
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == '撤销',
                ),
              )
              .onPressed,
          isNotNull,
        );
        await tester.tap(find.text('裁剪'));
        await tester.pumpAndSettle();
        expect(
          tester.state<CropImagePageState>(find.byType(CropImagePage)),
          same(crop),
        );
        await tester.tap(find.text('擦除'));
        await tester.pumpAndSettle();
        expect(
          tester.state<EraseImagePageState>(find.byType(EraseImagePage)),
          same(erase),
        );
        expect(enabled(tester), isTrue);
        await tester.tap(
          find.byWidgetPredicate((w) => w is IconButton && w.tooltip == '撤销'),
        );
        await tester.pump();
        expect(enabled(tester), isFalse);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == '恢复',
                ),
              )
              .onPressed,
          isNotNull,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          1,
        );
        expect(tester.takeException(), isNull);
        final mask = session.erase;
        for (var i = 0; i < 12; i++) {
          await tester.tap(find.text('裁剪'));
          await tester.pump();
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            0,
          );
          await tester.tap(find.text('擦除'));
          await tester.pump();
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            1,
          );
          expect(session.image, same(original));
          expect(session.crop, same(cropParameters));
          expect(session.erase, same(mask));
        }
        // Cropping stays undoable after applied erasure and repeated switches.
        await tester.tap(find.text('裁剪'));
        await tester.pump();
        await tester.tap(find.byTooltip('撤销'));
        await tester.pumpAndSettle();
        expect(session.crop!.sameAs(session.initialCrop), isTrue);
        expect(session.erase, same(mask));
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
