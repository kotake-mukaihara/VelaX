import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'crop_geometry.dart';
import 'crop_image_renderer.dart';
import 'erase_image_renderer.dart';

/// An immutable, source-coordinate vector mask. Pending strokes are selections,
/// not applied edits, and are intentionally excluded from preview/export masks.
class EraseState {
  EraseState({
    List<EraseStroke> erased = const [],
    List<EraseStroke> pending = const [],
  }) : erased = List.unmodifiable(erased),
       pending = List.unmodifiable(pending);

  final List<EraseStroke> erased;
  final List<EraseStroke> pending;
  bool get dirty => erased.isNotEmpty || pending.isNotEmpty;
}

class _History<T> {
  _History(T initial) : _entries = [initial];
  final List<T> _entries;
  int _index = 0;
  T get value => _entries[_index];
  bool get canUndo => _index > 0;
  bool get canRedo => _index < _entries.length - 1;

  void record(T value) {
    _entries.removeRange(_index + 1, _entries.length);
    _entries.add(value);
    _index++;
  }

  bool move(int direction) {
    if (direction != -1 && direction != 1) return false;
    if (direction < 0 ? !canUndo : !canRedo) return false;
    _index += direction;
    return true;
  }
}

/// Owns one decoded original for the entire editor lifetime. Tools keep only
/// gesture/camera UI state; committed edits and their histories live here.
/// Switching tools never invokes this class's loading or export operations.
class EditSession extends ChangeNotifier {
  EditSession(
    this.imagePath, {
    Future<ui.Image> Function(String path)? imageLoader,
  }) {
    ready = _load(imageLoader ?? _decode);
  }

  final String imagePath;
  late final Future<void> ready;
  ui.Image? _image;
  ui.Image? get image => _image;
  String? _error;
  String? get error => _error;
  bool _disposed = false;
  late final CropState initialCrop;
  _History<CropState>? _crops;
  final _erasures = _History(EraseState());
  ui.Size get imageSize =>
      ui.Size(_image!.width.toDouble(), _image!.height.toDouble());
  CropState? get crop => _crops?.value;
  EraseState get erase => _erasures.value;
  bool get canUndoCrop => _crops?.canUndo ?? false;
  bool get canRedoCrop => _crops?.canRedo ?? false;
  bool get canUndoErase => _erasures.canUndo;
  bool get canRedoErase => _erasures.canRedo;
  bool get hasAppliedEdits =>
      crop != null && (!crop!.sameAs(initialCrop) || erase.erased.isNotEmpty);

  static Future<ui.Image> _decode(String path) async {
    final codec = await ui.instantiateImageCodec(
      await File(path).readAsBytes(),
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  Future<void> _load(Future<ui.Image> Function(String) loader) async {
    try {
      final loaded = await loader(imagePath);
      if (_disposed) {
        loaded.dispose();
        return;
      }
      _image = loaded;
      initialCrop = CropState.initial(imageSize);
      _crops = _History(initialCrop);
    } catch (_) {
      if (!_disposed) _error = '照片无法读取，请返回重新选择';
    }
    if (!_disposed) notifyListeners();
  }

  void setCrop(CropState value) {
    if (_disposed || _crops == null) return;
    final next = coverCrop(value, imageSize);
    if (crop!.sameAs(next)) return;
    _crops!.record(next);
    notifyListeners();
  }

  void undoCrop(int direction) {
    if (!_disposed && (_crops?.move(direction) ?? false)) notifyListeners();
  }

  void addSelection(EraseStroke stroke) => _recordErase(
    EraseState(erased: erase.erased, pending: [...erase.pending, stroke]),
  );

  void applyErase() {
    if (erase.pending.isEmpty) return;
    _recordErase(EraseState(erased: [...erase.erased, ...erase.pending]));
  }

  void resetErase() {
    if (erase.dirty) _recordErase(EraseState());
  }

  void _recordErase(EraseState value) {
    if (_disposed || _image == null) return;
    _erasures.record(value);
    notifyListeners();
  }

  void undoErase(int direction) {
    if (!_disposed && _erasures.move(direction)) notifyListeners();
  }

  /// Inverts the exact preview transform, including mirror and tilt.
  ui.Offset toSource(ui.Offset point, {CropState? transform}) {
    final state = transform ?? crop!;
    final local = rotatePoint(point - state.offset, -state.angle) / state.scale;
    return ui.Offset(state.mirrored ? -local.dx : local.dx, local.dy) +
        imageSize.center(ui.Offset.zero);
  }

  /// Freeze the visible crop into each stroke, so uncropping later does not
  /// reveal erased pixels that were outside the selection when it was drawn.
  List<ui.Offset> get selectionClip =>
      cropCorners(crop!.crop).map(toSource).toList(growable: false);

  Future<Uint8List> exportPng() async {
    await ready;
    if (_disposed || _image == null) throw StateError(error ?? '编辑已关闭');
    // Keep the original alive if the editor closes during asynchronous export.
    final original = _image!.clone();
    final state = crop!;
    final strokes = erase.erased;
    try {
      return await renderCrop(original, state, strokes: strokes);
    } finally {
      original.dispose();
    }
  }

  /// The caller owns the returned temporary file, or the unchanged source path.
  Future<String> exportImage() async {
    await ready;
    if (_disposed || _image == null) throw StateError(error ?? '编辑已关闭');
    if (!hasAppliedEdits) return imagePath;
    final bytes = await exportPng();
    if (_disposed) throw StateError('编辑已关闭');
    final directory = await getTemporaryDirectory();
    final output = File(
      p.join(directory.path, 'velax_edit_${const Uuid().v4()}.png'),
    );
    try {
      await output.writeAsBytes(bytes, flush: true);
      if (_disposed) throw StateError('编辑已关闭');
      return output.path;
    } catch (_) {
      if (await output.exists()) await output.delete();
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _image?.dispose();
    _image = null;
    super.dispose();
  }
}
