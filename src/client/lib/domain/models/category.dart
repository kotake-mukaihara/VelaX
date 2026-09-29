class Category {
  const Category({
    required this.id,
    required this.name,
    this.parentId,
    required this.isPreset,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String name;
  final String? parentId;
  final bool isPreset;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
}
