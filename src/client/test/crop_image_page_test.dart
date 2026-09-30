import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velax/features/wardrobe/crop_image_page.dart';
import 'package:velax/features/wardrobe/crop_geometry.dart';
import 'package:velax/features/wardrobe/edit_image_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File source;
  setUpAll(() async {
    directory = await Directory.systemTemp.createTemp('velax_crop_test_');
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 400, 600),
      Paint()..color = const Color(0xFFB8C1B5),
    );
    canvas.drawPath(
      Path()
        ..moveTo(130, 110)
        ..lineTo(65, 165)
        ..lineTo(90, 260)
        ..lineTo(135, 240)
        ..lineTo(125, 460)
        ..lineTo(280, 460)
        ..lineTo(270, 240)
        ..lineTo(315, 260)
        ..lineTo(340, 165)
        ..lineTo(275, 110)
        ..lineTo(235, 130)
        ..lineTo(175, 130)
        ..close(),
      Paint()..color = const Color(0xFFF5F3EA),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(400, 600);
    picture.dispose();
    source = File('${directory.path}/source.png');
    await source.writeAsBytes(
      (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
          .asUint8List(),
    );
    image.dispose();
  });
  tearDownAll(() async {
    for (final entry in await directory.list().toList()) {
      await entry.delete();
    }
    await directory.delete();
  });

  Future<void> loaded(WidgetTester tester) async {
    for (
      var i = 0;
      i < 100 && find.byKey(const ValueKey('crop-tilt')).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('crop-tilt')), findsOneWidget);
  }

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (_) => CropImagePage(imagePath: source.path),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await loaded(tester);
  }

  bool canComplete(WidgetTester tester) =>
      tester
          .widget<TextButton>(find.byKey(const ValueKey('crop-complete')))
          .onPressed !=
      null;

  CropState previewState(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(const ValueKey('crop-preview')),
        matching: find.byType(CustomPaint),
      ),
    );
    final dynamic painter = paint.foregroundPainter;
    return painter.state as CropState;
  }

  testWidgets(
    'pinch anchors at fingers and parallel pan continues from current position',
    (tester) async {
      await open(tester);
      final preview = tester.getRect(
        find.byKey(const ValueKey('crop-preview')),
      );
      final viewScale = math.min(
        (preview.width - 64) / 400,
        (preview.height - 48) / 600,
      );
      final focal = preview.center + const Offset(25, -30);
      final initial = previewState(tester);
      final first = await tester.startGesture(
        focal - const Offset(45, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        focal + const Offset(45, 0),
        pointer: 2,
      );
      await first.moveTo(focal - const Offset(90, 0));
      await second.moveTo(focal + const Offset(90, 0));
      await tester.pump();
      final zoomed = previewState(tester);
      expect(find.text('重置'), findsNothing);
      expect(zoomed.scale, closeTo(2, 0.00001));
      expect(
        (zoomed.offset - const Offset(-25, 30) / viewScale).distance,
        lessThan(0.0001),
      );
      expect(zoomed.crop, initial.crop);
      await first.up();
      await tester.pump();
      expect(previewState(tester).sameAs(zoomed), isTrue);
      expect(find.text('重置'), findsNothing);
      await second.up();
      await tester.pumpAndSettle();
      expect(find.text('重置'), findsOneWidget);

      final panStart = previewState(tester);
      final a = await tester.startGesture(
        preview.center - const Offset(45, 0),
        pointer: 3,
      );
      final b = await tester.startGesture(
        preview.center + const Offset(45, 0),
        pointer: 4,
      );
      await tester.pump();
      expect(
        previewState(tester).sameAs(panStart),
        isTrue,
        reason: 'finger down must not reset position',
      );
      await a.moveBy(const Offset(20, 15));
      await b.moveBy(const Offset(20, 15));
      await tester.pump();
      final moved = previewState(tester);
      expect(find.text('重置'), findsOneWidget);
      expect(moved.scale, closeTo(panStart.scale, 0.000001));
      expect(
        (moved.offset - panStart.offset - const Offset(20, 15) / viewScale)
            .distance,
        lessThan(0.0001),
      );
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(previewState(tester).sameAs(moved), isTrue);
      await tester.tap(find.byTooltip('撤销'));
      await tester.pumpAndSettle();
      expect(previewState(tester).sameAs(panStart), isTrue);
      await tester.tap(find.byTooltip('撤销'));
      await tester.pumpAndSettle();
      expect(previewState(tester).sameAs(initial), isTrue);
    },
  );

  testWidgets(
    'two fingers override a resize handle and cancellation restores one gesture',
    (tester) async {
      await open(tester);
      final preview = tester.getRect(
        find.byKey(const ValueKey('crop-preview')),
      );
      final scale = math.min(
        (preview.width - 64) / 400,
        (preview.height - 48) / 600,
      );
      final corner = preview.center - Offset(200 * scale, 300 * scale);
      final first = await tester.startGesture(corner, pointer: 1);
      final second = await tester.startGesture(
        corner + const Offset(90, 70),
        pointer: 2,
      );
      final initial = previewState(tester);
      await first.moveBy(const Offset(40, 20));
      await second.moveBy(const Offset(40, 20));
      await tester.pump();
      expect(previewState(tester).crop, initial.crop);
      expect(previewState(tester).offset.distance, greaterThan(0));
      final beforeLift = previewState(tester);
      await first.up();
      await tester.pump();
      expect(previewState(tester).sameAs(beforeLift), isTrue);
      await second.moveBy(const Offset(10, 0));
      await tester.pump();
      expect(
        (previewState(tester).offset -
                beforeLift.offset -
                Offset(10 / scale, 0))
            .distance,
        lessThan(0.0001),
      );
      await second.cancel();
      await tester.pumpAndSettle();
      expect(previewState(tester).sameAs(initial), isTrue);
      expect(canComplete(tester), isFalse);
    },
  );

  testWidgets(
    'under-zoom and overscroll animate to coverage only after both fingers lift',
    (tester) async {
      await open(tester);
      final preview = tester.getRect(
        find.byKey(const ValueKey('crop-preview')),
      );
      final first = await tester.startGesture(
        preview.center - const Offset(90, 0),
        pointer: 1,
      );
      final second = await tester.startGesture(
        preview.center + const Offset(90, 0),
        pointer: 2,
      );
      final initial = previewState(tester);
      await first.moveTo(preview.center + const Offset(5, 45));
      await second.moveTo(preview.center + const Offset(95, 45));
      await tester.pump();
      final undersized = previewState(tester);
      expect(find.text('重置'), findsNothing);
      expect(undersized.scale, closeTo(0.5, 0.000001));
      expect(cropIsCovered(undersized, const Size(400, 600)), isFalse);
      expect(undersized.crop, initial.crop);
      await first.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        previewState(tester).sameAs(undersized),
        isTrue,
        reason: 'one finger is still touching',
      );
      await second.up();
      await tester.pump();
      expect(
        previewState(tester).scale,
        closeTo(0.5, 0.000001),
        reason: 'scale must animate rather than jump',
      );
      await tester.pump(const Duration(milliseconds: 70));
      final during = previewState(tester);
      expect(find.text('重置'), findsNothing);
      expect(during.scale, greaterThan(0.5));
      expect(during.scale, lessThan(1));
      await tester.pumpAndSettle();
      expect(previewState(tester).sameAs(initial), isTrue);
      expect(canComplete(tester), isFalse);
      expect(find.text('重置'), findsNothing);

      // Repeat after tilting and zooming: coverage must use rotated image axes.
      await tester.drag(
        find.byKey(const ValueKey('crop-tilt')),
        const Offset(40, 0),
      );
      await tester.pumpAndSettle();
      final tilted = previewState(tester);
      final a = await tester.startGesture(
        preview.center - const Offset(40, 0),
        pointer: 3,
      );
      final b = await tester.startGesture(
        preview.center + const Offset(40, 0),
        pointer: 4,
      );
      await a.moveTo(preview.center + const Offset(-50, 180));
      await b.moveTo(preview.center + const Offset(110, 180));
      await tester.pump();
      final outside = previewState(tester);
      expect(outside.scale, closeTo(tilted.scale * 2, 0.000001));
      final expected = coverCrop(outside, const Size(400, 600));
      await a.up();
      await b.up();
      await tester.pumpAndSettle();
      expect(previewState(tester).sameAs(expected), isTrue);
      expect(cropIsCovered(previewState(tester), const Size(400, 600)), isTrue);
      expect(previewState(tester).crop, tilted.crop);
      await tester.tap(find.byTooltip('撤销'));
      await tester.pumpAndSettle();
      expect(previewState(tester).sameAs(tilted), isTrue);
      await tester.tap(find.byTooltip('恢复'));
      await tester.pumpAndSettle();
      expect(previewState(tester).sameAs(expected), isTrue);
    },
  );

  testWidgets(
    'clean exit, dirty confirmation, undo redo reset and stable ratio layout',
    (tester) async {
      await open(tester);
      expect(canComplete(tester), isFalse);
      expect(find.text('重置'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('打开'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('打开'));
      await loaded(tester);

      final square = find.byKey(const ValueKey('crop-ratio-1:1'));
      final before = tester.getRect(square);
      await tester.tap(square);
      await tester.pumpAndSettle();
      expect(tester.getRect(square), before);
      expect(canComplete(tester), isTrue);
      await tester.tap(find.byTooltip('撤销'));
      await tester.pumpAndSettle();
      expect(canComplete(tester), isFalse);
      await tester.tap(find.byTooltip('恢复'));
      await tester.pumpAndSettle();
      expect(canComplete(tester), isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('确定放弃对图片的修改吗？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重置'));
      await tester.pumpAndSettle();
      expect(canComplete(tester), isFalse);
      expect(find.text('重置'), findsNothing);
      await tester.tap(find.byTooltip('逆时针旋转90°'));
      await tester.pumpAndSettle();
      expect(canComplete(tester), isTrue);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) => widget is IconButton && widget.tooltip == '恢复',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃'));
      await tester.pumpAndSettle();
      expect(find.text('打开'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'edge resize is one undo step; overscroll snaps back; all ratios scroll',
    (tester) async {
      await open(tester);
      final preview = tester.getRect(
        find.byKey(const ValueKey('crop-preview')),
      );
      final scale = (preview.height - 48) / 600;
      final topLeft = preview.center - Offset(200 * scale, 300 * scale);
      await tester.dragFrom(topLeft, const Offset(55, 60));
      await tester.pumpAndSettle();
      expect(canComplete(tester), isTrue);
      await tester.tap(find.byTooltip('撤销'));
      await tester.pumpAndSettle();
      expect(canComplete(tester), isFalse);
      await tester.dragFrom(preview.center, const Offset(250, 180));
      await tester.pumpAndSettle();
      expect(
        canComplete(tester),
        isFalse,
        reason: 'full-image crop cannot retain any pan',
      );
      await tester.drag(
        find.byKey(const ValueKey('crop-ratios')),
        const Offset(-600, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('crop-ratio-7:5')));
      await tester.pumpAndSettle();
      expect(canComplete(tester), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'mouse can drag ratios both ways and select a ratio',
    (tester) async {
      await open(tester);
      final ratios = find.byKey(const ValueKey('crop-ratios'));
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: ratios, matching: find.byType(Scrollable)),
      );
      expect(scrollable.position.pixels, 0);
      await tester.drag(
        ratios,
        const Offset(-600, 0),
        kind: ui.PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, greaterThan(0));
      expect(canComplete(tester), isFalse);
      await tester.tap(find.byKey(const ValueKey('crop-ratio-7:5')));
      await tester.pumpAndSettle();
      expect(canComplete(tester), isTrue);
      await tester.drag(
        ratios,
        const Offset(600, 0),
        kind: ui.PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, 0);
      expect(
        find.byKey(const ValueKey('crop-ratio-自由')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.macOS,
    }),
  );

  testWidgets('tilt and mirror are undoable, and landscape has no overflow', (
    tester,
  ) async {
    await open(tester, size: const Size(844, 390));
    final slider = find.byKey(const ValueKey('crop-tilt'));
    await tester.drag(slider, const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(canComplete(tester), isTrue);
    expect(tester.widget<Slider>(slider).value, greaterThan(0));
    await tester.tap(find.byTooltip('水平镜像翻转'));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider).value, lessThan(0));
    await tester.tap(find.byTooltip('撤销'));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider).value, greaterThan(0));
    await tester.tap(find.byTooltip('撤销'));
    await tester.pumpAndSettle();
    expect(canComplete(tester), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed crop returns a PNG to the editor and next page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => directory.path,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          ),
    );
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(home: EditImagePage(imagePath: source.path)),
      ),
    );
    await tester.tap(find.text('裁剪'));
    await loaded(tester);
    await tester.tap(find.byKey(const ValueKey('crop-ratio-1:1')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final render =
          boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final screenshot = await render.toImage();
      final file = File('build/crop-preview.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(
        (await screenshot.toByteData(format: ui.ImageByteFormat.png))!.buffer
            .asUint8List(),
      );
      screenshot.dispose();
    });
    await tester.tap(find.text('下一步'));
    for (var i = 0; i < 100 && find.byType(Image).evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(find.text('下一步'), findsNothing);
    final provider =
        tester.widget<Image>(find.byType(Image)).image as FileImage;
    expect(provider.file.path, isNot(source.path));
    await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        await provider.file.readAsBytes(),
      );
      final output = (await codec.getNextFrame()).image;
      expect(output.width, 400);
      expect(output.height, 400);
      output.dispose();
      codec.dispose();
    });
    expect(
      (tester.widget<Image>(find.byType(Image).last).image as FileImage)
          .file
          .path,
      provider.file.path,
    );
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
  });
}
