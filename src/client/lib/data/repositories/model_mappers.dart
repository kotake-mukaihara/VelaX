import '../../domain/models/category.dart';
import '../../domain/models/brand.dart';
import '../../domain/models/color.dart';
import '../database/app_database.dart';

Category mapCategory(CategoryRow r) => Category(
  id: r.id,
  name: r.name,
  parentId: r.parentId,
  isPreset: r.isPreset,
  sortOrder: r.sortOrder,
  createdAt: r.createdAt,
  updatedAt: r.updatedAt,
);
Brand mapBrand(BrandRow r) => Brand(
  id: r.id,
  name: r.name,
  createdAt: r.createdAt,
  updatedAt: r.updatedAt,
);
Color mapColor(ColorRow r) => Color(id: r.id, name: r.name, hex: r.hex);
