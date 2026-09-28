import 'package:flutter/material.dart';

import 'data/database/app_database.dart';
import 'data/repositories/clothing_item_repository.dart';
import 'features/home/home_page.dart';

void main() => runApp(const MainApp());

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  late final AppDatabase _database = AppDatabase();
  late final ClothingItemRepository _items = ClothingItemRepository(_database);

  @override
  void dispose() {
    _database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '栖色 Velax',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF65745B)),
      scaffoldBackgroundColor: const Color(0xFFFAF9F6),
    ),
    home: HomePage(loadItems: _items.items),
  );
}
