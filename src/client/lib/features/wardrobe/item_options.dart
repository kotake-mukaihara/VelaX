import '../../domain/models/brand.dart';
import '../../domain/models/category.dart';
import '../../domain/models/color.dart';

class ItemOptions {
  const ItemOptions({
    required this.categories,
    required this.brands,
    required this.colors,
    required this.createBrand,
    this.saveItem,
  });

  final Future<List<Category>> Function() categories;
  final Future<List<Brand>> Function() brands;
  final Future<List<Color>> Function() colors;
  final Future<Brand> Function(String) createBrand;
  final Future<void> Function(
    String image,
    Category category,
    Brand? brand,
    String? size,
    List<Color?> colors,
    String note,
  )?
  saveItem;
}
