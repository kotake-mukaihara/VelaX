// Drift CHECK expressions refer to the column being declared.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'clothing_items.dart';
import 'colors.dart';

@DataClassName('SecondaryColorRow')
class ItemSecondaryColors extends Table {
  TextColumn get itemId =>
      text().references(ClothingItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get colorId => text().references(Colors, #id)();
  IntColumn get position => integer().check(position.isBetweenValues(0, 1))();
  @override
  Set<Column> get primaryKey => {itemId, colorId};
  @override
  List<Set<Column>> get uniqueKeys => [
    {itemId, position},
  ];
}
