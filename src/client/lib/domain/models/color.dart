/// Wardrobe color metadata, independent of Flutter's rendering Color.
class Color {
  const Color({required this.id, required this.name, required this.hex});
  final String id;
  final String name;
  final String hex;
}
