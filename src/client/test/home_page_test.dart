import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velax/theme/themed_app.dart';
import 'package:velax/features/home/home_page.dart';

void main() {
  testWidgets('responsive navigation preserves selected tab', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ThemedApp(home: HomePage(loadItems: () async => [])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(320, 844);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('查看衣橱数据'), findsOneWidget);
    await tester.tap(find.text('查看衣橱数据'));
    await tester.pumpAndSettle();
    expect(find.text('数据统计'), findsOneWidget);
    expect(find.text('风格画像'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('查看衣橱数据'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    await tester.tap(find.text('数据备份与迁移'));
    await tester.pumpAndSettle();
    expect(find.text('当前暂不支持云同步'), findsOneWidget);
    expect(find.text('本机数据'), findsOneWidget);
    expect(find.text('数据导出'), findsOneWidget);
    expect(find.text('数据导入'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(find.text('栖色 VelaX'), findsOneWidget);
    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty wardrobe and overview navigation', (tester) async {
    await tester.pumpWidget(
      ThemedApp(home: HomePage(loadItems: () async => [])),
    );
    await tester.pumpAndSettle();
    expect(find.text('栖色 VelaX'), findsOneWidget);
    expect(find.text('共 0 件衣物'), findsOneWidget);
    expect(find.text('0 件', findRichText: true), findsNWidgets(2));
    expect(find.text('0 双', findRichText: true), findsOneWidget);
    expect(find.text('还没有衣物'), findsOneWidget);
    await tester.tap(find.byTooltip('查看衣橱数据'));
    await tester.pumpAndSettle();
    expect(find.text('数据统计'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(find.text('最近添加'), findsOneWidget);
  });
}
