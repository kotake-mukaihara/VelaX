import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import 'model_mappers.dart';
import '../../domain/models/brand.dart';

class BrandRepository {
  BrandRepository(this.database);
  final AppDatabase database;
  static const _uuid = Uuid();

  String _name(String value) {
    if (value.trim().isEmpty) throw ArgumentError('Name must not be blank.');
    return value.trim();
  }

  Future<List<Brand>> brands() async => (await (database.select(
    database.brands,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).get()).map(mapBrand).toList();
  Future<Brand> createBrand(String name) async {
    final now = DateTime.now().toUtc();
    final row = BrandRow(
      id: _uuid.v4(),
      name: _name(name),
      createdAt: now,
      updatedAt: now,
    );
    await database.into(database.brands).insert(row);
    return mapBrand(row);
  }

  Future<void> updateBrand(String id, String name) async {
    final count =
        await (database.update(
          database.brands,
        )..where((t) => t.id.equals(id))).write(
          BrandsCompanion(
            name: Value(_name(name)),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (count == 0) throw StateError('Brand not found.');
  }

  Future<void> deleteBrand(String id) =>
      (database.delete(database.brands)..where((t) => t.id.equals(id))).go();
}
