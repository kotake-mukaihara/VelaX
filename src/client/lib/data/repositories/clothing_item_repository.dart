import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'model_mappers.dart';
import '../../domain/models/clothing_item.dart';
import '../../domain/enums/apparel_size.dart';
import '../../domain/enums/shoe_size.dart';
import 'color_repository.dart';

class ClothingItemRepository {
  ClothingItemRepository(this.database);
  final AppDatabase database;
  static const _uuid = Uuid();

  Iterable<String> _sizesForRoot(String rootId) => switch (rootId) {
    'top' || 'bottom' => ApparelSize.values.map((size) => size.value),
    'shoes' => ShoeSize.values.map((size) => size.value),
    _ => const <String>[],
  };

  /// With [id] updates an existing item; omitted nullable fields are cleared.
  /// Image is a path supplied by LocalImageStore, never image bytes.
  Future<ClothingItem> saveItem({
    String? id,
    required String image,
    required String categoryId,
    String? brandId,
    String? size,
    String? primaryColorId,
    List<String> secondaryColorIds = const [],
    String? note,
  }) => database.transaction(() async {
    if (image.trim().isEmpty) {
      throw ArgumentError('Image path must not be blank.');
    }
    if (secondaryColorIds.length > 2 ||
        secondaryColorIds.toSet().length != secondaryColorIds.length) {
      throw ArgumentError('At most two distinct secondary colors are allowed.');
    }
    final category = await (database.select(
      database.categories,
    )..where((t) => t.id.equals(categoryId))).getSingleOrNull();
    if (category == null) throw ArgumentError('Category not found.');
    if (size != null &&
        !_sizesForRoot(category.parentId ?? category.id).contains(size)) {
      throw ArgumentError('Size does not belong to this category.');
    }
    final old = id == null
        ? null
        : await (database.select(
            database.clothingItems,
          )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (id != null && old == null) throw StateError('Clothing item not found.');
    final now = DateTime.now().toUtc();
    final itemId = id ?? _uuid.v4();
    final row = ClothingItemRow(
      id: itemId,
      image: image,
      categoryId: categoryId,
      brandId: brandId,
      size: size,
      primaryColorId: primaryColorId,
      note: note == null || note.trim().isEmpty ? null : note.trim(),
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    await database
        .into(database.clothingItems)
        .insertOnConflictUpdate(row.toCompanion(false));
    await (database.delete(
      database.itemSecondaryColors,
    )..where((t) => t.itemId.equals(itemId))).go();
    for (var i = 0; i < secondaryColorIds.length; i++) {
      await database
          .into(database.itemSecondaryColors)
          .insert(
            ItemSecondaryColorsCompanion.insert(
              itemId: itemId,
              colorId: secondaryColorIds[i],
              position: i,
            ),
          );
    }
    return (await getItem(itemId))!;
  });

  Future<ClothingItem?> getItem(String id) => database.transaction(() async {
    final row = await (database.select(
      database.clothingItems,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _hydrate(row);
  });

  Future<List<ClothingItem>> items() => database.transaction(() async {
    final rows =
        await (database.select(database.clothingItems)..orderBy([
              (t) => OrderingTerm.desc(t.createdAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get();
    return Future.wait(rows.map(_hydrate));
  });

  Future<ClothingItem> _hydrate(ClothingItemRow row) async {
    final category = await (database.select(
      database.categories,
    )..where((t) => t.id.equals(row.categoryId))).getSingle();
    final brand = row.brandId == null
        ? null
        : await (database.select(
            database.brands,
          )..where((t) => t.id.equals(row.brandId!))).getSingle();
    final palette = {
      for (final c in await ColorRepository(database).colors()) c.id: c,
    };
    final secondary =
        await (database.select(database.itemSecondaryColors)
              ..where((t) => t.itemId.equals(row.id))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    return ClothingItem(
      id: row.id,
      image: row.image,
      category: mapCategory(category),
      brand: brand == null ? null : mapBrand(brand),
      size: row.size,
      primaryColor: palette[row.primaryColorId],
      secondaryColors: secondary.map((r) => palette[r.colorId]!).toList(),
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> deleteItem(String id) => (database.delete(
    database.clothingItems,
  )..where((t) => t.id.equals(id))).go();
}
