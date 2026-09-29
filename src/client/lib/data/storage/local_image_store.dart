import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Copies picked images into application-owned storage before saving their paths.
/// Files are retained on item deletion so shared paths never lose their data.
class LocalImageStore {
  LocalImageStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _directory;

  Future<String> importFile(File source) async {
    final root = await _directory();
    final images = await Directory(p.join(root.path, 'wardrobe_images'))
        .create(recursive: true);
    final target = p.join(
      images.path,
      '${const Uuid().v4()}${p.extension(source.path)}',
    );
    await source.copy(target);
    return target;
  }
}
