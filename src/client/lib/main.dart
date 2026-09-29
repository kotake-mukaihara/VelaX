import 'package:flutter/material.dart';

import 'data/database/app_database.dart';
import 'data/repositories/clothing_item_repository.dart';
import 'data/repositories/category_repository.dart';
import 'features/home/home_page.dart';
import 'theme/themed_app.dart';
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
  Widget build(BuildContext context) => ThemedApp(
    home: HomePage(
      loadItems: _items.items,
      itemOptions: ItemOptions(
        categories: CategoryRepository(_database).categories,
        brands: BrandRepository(_database).brands,
        colors: ColorRepository(_database).colors,
        createBrand: BrandRepository(_database).createBrand,
        deleteItem: _items.deleteItem,
        updateItem: (item) => _items.saveItem(
          id: item.id,
          image: item.image,
          categoryId: item.category.id,
          brandId: item.brand?.id,
          size: item.size,
          primaryColorId: item.primaryColor?.id,
          secondaryColorIds: item.secondaryColors.map((c) => c.id).toList(),
          note: item.note,
        ),
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
