// Drift CHECK expressions refer to the column being declared.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

@DataClassName('CategoryRow')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name =>
      text().check(name.trim().length.isBiggerThanValue(0))();
  TextColumn get parentId => text().nullable().references(Categories, #id)();
  BoolColumn get isPreset => boolean()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}
