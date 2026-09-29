// Drift CHECK expressions refer to the column being declared.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

@DataClassName('ColorRow')
class Colors extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get hex => text()();
  @override
  Set<Column> get primaryKey => {id};
}
