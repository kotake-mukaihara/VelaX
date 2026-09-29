import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velax/features/home/home_page.dart';
import 'package:velax/theme/themed_app.dart';

void main() {
  testWidgets('manual and system themes apply across navigation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 844);
    final dispatcher = tester.binding.platformDispatcher;
    dispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(dispatcher.clearPlatformBrightnessTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ThemedApp(home: HomePage(loadItems: () async => [])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    Brightness brightness() =>
        Theme.of(tester.element(find.byType(Switch))).brightness;
    Switch toggle() => tester.widget<Switch>(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    expect(toggle().value, isTrue);

    await tester.tap(find.text('跟随系统'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
    expect(toggle().onChanged, isNull);
    expect(toggle().value, isFalse);
    dispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    expect(toggle().value, isTrue);
    expect(toggle().onChanged, isNull);

    await tester.tap(find.text('数据备份与迁移'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('本机数据'))).brightness,
      Brightness.dark,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('最近添加'))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(toggle().onChanged, isNull);

    await tester.tap(find.text('跟随系统'));
    await tester.pumpAndSettle();
    expect(toggle().onChanged, isNotNull);
    dispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
    expect(tester.takeException(), isNull);
  });
}
