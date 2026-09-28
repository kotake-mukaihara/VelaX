// Drift CHECK expressions refer to the column being declared.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

@DataClassName('BrandRow')
class Brands extends Table {
  TextColumn get id => text()();
  TextColumn get name =>
      text().check(name.trim().length.isBiggerThanValue(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}
