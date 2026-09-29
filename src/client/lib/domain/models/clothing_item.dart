import 'brand.dart';
import 'category.dart';
import 'color.dart';

class ClothingItem {
  ClothingItem({
    required this.id,
    required this.image,
    required this.category,
    this.brand,
    this.size,
    this.primaryColor,
    List<Color> secondaryColors = const [],
    String? note,
    required this.createdAt,
    required this.updatedAt,
  }) : secondaryColors = List.unmodifiable(secondaryColors),
       note = note == null || note.trim().isEmpty ? null : note.trim() {
    if (secondaryColors.length > 2 ||
        secondaryColors.map((c) => c.id).toSet().length !=
            secondaryColors.length) {
      throw ArgumentError(
        'Secondary colors must be unique and contain at most two colors.',
      );
    }
  }
  final String id;
  final String image;
  final Category category;
  final Brand? brand;
  final String? size;
  final Color? primaryColor;
  final List<Color> secondaryColors;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;
}
