import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'model_mappers.dart';
import '../../domain/models/category.dart';

class CategoryRepository {
  CategoryRepository(this.database);
  final AppDatabase database;
  static const _uuid = Uuid();

  String _name(String value) {
    if (value.trim().isEmpty) throw ArgumentError('Name must not be blank.');
    return value.trim();
  }

  Future<List<Category>> categories() async =>
      (await (database.select(database.categories)..orderBy([
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.id),
              ]))
              .get())
          .map(mapCategory)
          .toList();
  Future<Category> createCategory(
    String name, {
    String? parentId,
    int sortOrder = 0,
  }) => database.transaction(() async {
    if (parentId != null) {
      final parent = await (database.select(
        database.categories,
      )..where((t) => t.id.equals(parentId))).getSingleOrNull();
      if (parent == null || parent.parentId != null) {
        throw ArgumentError('Parent must be an existing root category.');
      }
    }
    final now = DateTime.now().toUtc();
    final row = CategoryRow(
      id: 'custom_${_uuid.v4()}',
      name: _name(name),
      parentId: parentId,
      isPreset: false,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
    await database.into(database.categories).insert(row);
    return mapCategory(row);
  });

  Future<void> updateCategory(
    String id, {
    required String name,
    required int sortOrder,
  }) async {
    final count =
        await (database.update(
          database.categories,
        )..where((t) => t.id.equals(id) & t.isPreset.equals(false))).write(
          CategoriesCompanion(
            name: Value(_name(name)),
            sortOrder: Value(sortOrder),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (count == 0) throw StateError('Custom category not found.');
  }

  Future<void> deleteCategory(String id) async {
    final count = await (database.delete(
      database.categories,
    )..where((t) => t.id.equals(id) & t.isPreset.equals(false))).go();
    if (count == 0) throw StateError('Custom category not found.');
  }
}
