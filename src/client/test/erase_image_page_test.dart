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
      await tester.tap(find.byKey(const ValueKey('erase-apply')));
      await tester.pump();
      expect(enabled(tester), isFalse);
      await tester.tap(find.byTooltip('撤销'));
      await tester.pump();
      expect(enabled(tester), isTrue);
      await tester.tap(find.byTooltip('恢复'));
      await tester.pump();
      expect(enabled(tester), isFalse);
      await tester.tap(find.text('重置'));
      await tester.pump();
      expect(find.text('重置'), findsNothing);
      await tester.tap(find.byTooltip('撤销'));
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
}
