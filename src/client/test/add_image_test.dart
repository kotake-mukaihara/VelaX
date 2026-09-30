import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:velax/features/home/home_page.dart';

class FakePicker extends ImagePicker {
  ImageSource? source;
  XFile? result;
  bool fail = false;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    if (fail) throw PlatformException(code: 'camera_access_denied');
    return result;
  }
}

void main() {
  Future<void> openSheet(
    WidgetTester tester,
    FakePicker picker,
    TargetPlatform platform,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: HomePage(loadItems: () async => [], imagePicker: picker),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('衣橱'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('添加单品'));
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.macOS]) {
    testWidgets('$platform disables camera', (tester) async {
      final picker = FakePicker();
      await openSheet(tester, picker, platform);
      expect(find.text('Windows/MacOS端暂不支持'), findsOneWidget);
      await tester.tap(find.text('拍照'));
      await tester.pumpAndSettle();
      expect(picker.source, isNull);
      expect(find.text('从相册选择'), findsOneWidget);
    });
  }

  for (final source in ImageSource.values) {
    testWidgets('$source opens editor and returns without sheet', (
      tester,
    ) async {
      final picker = FakePicker()..result = XFile('/missing-image.jpg');
      await openSheet(tester, picker, TargetPlatform.android);
      await tester.tap(
        find.text(source == ImageSource.camera ? '拍照' : '从相册选择'),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(picker.source, source);
      expect(find.text('编辑图片'), findsOneWidget);
      for (final text in ['裁剪', '擦除', '下一步']) {
        expect(find.text(text), findsOneWidget);
      }
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('放弃编辑？'), findsOneWidget);
      await tester.tap(find.text('继续编辑'));
      await tester.pumpAndSettle();
      expect(find.text('编辑图片'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('放弃编辑？'), findsOneWidget);
      await tester.tap(find.text('放弃编辑'));
      await tester.pumpAndSettle();
      expect(find.text('衣橱'), findsNWidgets(2));
      expect(find.text('从相册选择'), findsNothing);
      expect(find.byTooltip('添加单品'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancel stays in wardrobe and permission failure can retry', (
    tester,
  ) async {
    final picker = FakePicker();
    await openSheet(tester, picker, TargetPlatform.android);
    await tester.tap(find.text('从相册选择'));
    await tester.pumpAndSettle();
    expect(find.text('衣橱'), findsNWidgets(2));
    expect(find.text('编辑图片'), findsNothing);
    picker.fail = true;
    await tester.tap(find.byTooltip('添加单品'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('拍照'));
    await tester.pumpAndSettle();
    expect(find.text('无法访问相机或相册，请在系统设置中允许访问后重试'), findsOneWidget);
    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNotNull,
    );
  });
}
