import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:velax/features/home/home_page.dart';

void main() {
  testWidgets('responsive navigation preserves selected tab', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: HomePage(loadItems: () async => [])),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('我的页面即将上线'), findsOneWidget);
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(find.text('栖色 Velax'), findsOneWidget);
    tester.view.physicalSize = const Size(800, 600);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty wardrobe and overview navigation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomePage(loadItems: () async => [])),
    );
    await tester.pumpAndSettle();
    expect(find.text('栖色 Velax'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(4));
    expect(find.text('还没有衣物'), findsOneWidget);
    await tester.tap(find.byTooltip('查看衣橱'));
    await tester.pumpAndSettle();
    expect(find.text('衣橱概览'), findsOneWidget);
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(find.text('最近添加'), findsOneWidget);
  });
}
