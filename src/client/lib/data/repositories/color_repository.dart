import '../../domain/models/color.dart';
import '../database/app_database.dart';
import 'model_mappers.dart';

class ColorRepository {
  ColorRepository(this.database);
  final AppDatabase database;

  Future<List<Color>> colors() async =>
      (await database.select(database.colors).get()).map(mapColor).toList();
}
