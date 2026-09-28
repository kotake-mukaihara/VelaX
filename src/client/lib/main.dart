import 'package:flutter/material.dart';

import 'data/database/app_database.dart';
import 'data/repositories/clothing_item_repository.dart';
import 'data/repositories/category_repository.dart';
import 'features/home/home_page.dart';
import 'data/repositories/brand_repository.dart';
import 'data/repositories/color_repository.dart';
import 'features/wardrobe/item_options.dart';
import 'data/storage/local_image_store.dart';

import 'dart:io';

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
    home: HomePage(
      loadItems: _items.items,
      itemOptions: ItemOptions(
        categories: CategoryRepository(_database).categories,
        brands: BrandRepository(_database).brands,
        colors: ColorRepository(_database).colors,
        createBrand: BrandRepository(_database).createBrand,
        saveItem: (image, category, brand, size, colors, note) async {
          final path = await LocalImageStore().importFile(File(image));
          await _items.saveItem(
            image: path,
            categoryId: category.id,
            brandId: brand?.id,
            size: size,
            primaryColorId: colors[0]?.id,
            secondaryColorIds: colors
                .skip(1)
                .where((color) => color != null)
                .map((color) => color!.id)
                .toList(),
            note: note,
          );
        },
      ),
      loadCategories: CategoryRepository(_database).categories,
    ),
  );
}
