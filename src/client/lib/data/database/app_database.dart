import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'seed/category_seed.dart';
import 'seed/color_seed.dart';
import 'tables/categories.dart';
import 'tables/brands.dart';
import 'tables/colors.dart';
import 'tables/clothing_items.dart';
import 'tables/clothing_item_colors.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Categories, Brands, Colors, ClothingItems, ItemSecondaryColors],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'velax'));
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedPresets();
    },
    beforeOpen: (_) async => customStatement('PRAGMA foreign_keys = ON'),
  );

  Future<void> seedPresets() => transaction(() async {
    final now = DateTime.now().toUtc();
    for (var i = 0; i < categoryPresets.length; i++) {
      final (id, name, parent) = categoryPresets[i];
      await into(categories).insert(
        CategoriesCompanion.insert(
          id: id,
          name: name,
          parentId: Value(parent),
          isPreset: true,
          sortOrder: i,
          createdAt: now,
          updatedAt: now,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    for (final (id, name, hex) in colorPresets) {
      await into(colors).insert(
        ColorsCompanion.insert(id: id, name: name, hex: hex),
        mode: InsertMode.insertOrIgnore,
      );
    }
  });
}
