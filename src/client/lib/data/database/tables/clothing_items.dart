// Drift CHECK expressions refer to the column being declared.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'categories.dart';
import 'brands.dart';
import 'colors.dart';

@DataClassName('ClothingItemRow')
class ClothingItems extends Table {
  TextColumn get id => text()();
  TextColumn get image =>
      text().check(image.trim().length.isBiggerThanValue(0))();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get brandId =>
      text().nullable().references(Brands, #id, onDelete: KeyAction.setNull)();
  TextColumn get size => text().nullable()();
  TextColumn get primaryColorId => text().nullable().references(Colors, #id)();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}
