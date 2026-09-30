import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:velax/features/wardrobe/crop_geometry.dart';
import 'package:velax/features/wardrobe/edit_session.dart';
import 'package:velax/features/wardrobe/erase_image_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ui.Image original;
  late EditSession session;
  var loads = 0;

  setUp(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 120, 80),
      ui.Paint()..color = const ui.Color(0xFFFF0000),
    );
    final picture = recorder.endRecording();
    original = await picture.toImage(120, 80);
    picture.dispose();
    loads = 0;
    session = EditSession(
      'not-read.png',
      imageLoader: (_) async {
        loads++;
        return original.clone();
      },
    );
    await session.ready;
  });

  tearDown(() {
    session.dispose();
    original.dispose();
  });

  Future<void> expectPixels({
    required int width,
    required int height,
    required Map<ui.Offset, int> alpha,
  }) async {
    final codec = await ui.instantiateImageCodec(await session.exportPng());
    final result = (await codec.getNextFrame()).image;
    codec.dispose();
    try {
      expect(result.width, width);
      expect(result.height, height);
      final pixels = (await result.toByteData())!;
      for (final entry in alpha.entries) {
        expect(
          pixels.getUint8(
            (entry.key.dy.toInt() * width + entry.key.dx.toInt()) * 4 + 3,
          ),
          entry.value,
          reason: 'alpha at ${entry.key}',
        );
      }
    } finally {
      result.dispose();
    }
  }

  test(
    'one original, independent tool histories and non-destructive reset',
    () async {
      final source = session.image;
      session.setCrop(selectCropRatio(session.crop!, '1:1', session.imageSize));
      final cropped = session.crop!;
      session.addSelection(EraseStroke([const ui.Offset(60, 40)], 16));
      expect(session.erase.erased, isEmpty);
      session.applyErase();
      expect(session.crop, same(cropped));
      session.undoCrop(-1);
      expect(session.crop!.sameAs(session.initialCrop), isTrue);
      expect(session.erase.erased, hasLength(1));
      session.undoErase(-1);
      expect(session.erase.pending, hasLength(1));
      expect(session.erase.erased, isEmpty);
      session.undoErase(1);
      session.undoCrop(1);
      expect(session.crop, same(cropped));
      session.resetErase();
      expect(session.crop, same(cropped));
      session.undoErase(-1);
      await expectPixels(
        width: 80,
        height: 80,
        alpha: {const ui.Offset(40, 40): 0, const ui.Offset(5, 5): 255},
      );
      expect(session.image, same(source));
      expect(loads, 1);
      final pixels = (await original.toByteData())!;
      expect(pixels.getUint8((40 * 120 + 60) * 4 + 3), 255);
    },
  );

  test(
    'mask follows rotation and mirror without replacing or resampling source',
    () async {
      session.addSelection(EraseStroke([const ui.Offset(20, 20)], 12));
      session.applyErase();
      session.setCrop(rotateCropLeft(session.crop!, session.imageSize));
      await expectPixels(
        width: 80,
        height: 120,
        alpha: {const ui.Offset(20, 100): 0, const ui.Offset(60, 20): 255},
      );
      session.setCrop(mirrorCrop(session.crop!));
      await expectPixels(
        width: 80,
        height: 120,
        alpha: {const ui.Offset(60, 100): 0, const ui.Offset(20, 20): 255},
      );
      session.setCrop(session.initialCrop);
      await expectPixels(
        width: 120,
        height: 80,
        alpha: {const ui.Offset(20, 20): 0, const ui.Offset(100, 60): 255},
      );
      expect(loads, 1);
    },
  );

  test('inverse hit testing includes tilt, pan, scale and mirror', () {
    for (final mirrored in [false, true]) {
      final state = session.crop!.copyWith(
        quarterTurns: 1,
        tilt: 23,
        scale: 2.3,
        offset: const ui.Offset(17, -8),
        mirrored: mirrored,
      );
      const source = ui.Offset(35, 51);
      final centered = source - session.imageSize.center(ui.Offset.zero);
      final projected =
          rotatePoint(
            ui.Offset(mirrored ? -centered.dx : centered.dx, centered.dy) *
                state.scale,
            state.angle,
          ) +
          state.offset;
      expect(
        (session.toSource(projected, transform: state) - source).distance,
        lessThan(0.000001),
      );
    }
  });

  test('uncropping restores hidden pixels beyond a stroke clip', () async {
    session.setCrop(
      session.crop!.copyWith(crop: const ui.Rect.fromLTWH(0, -40, 60, 80)),
    );
    session.addSelection(
      EraseStroke(
        [const ui.Offset(40, 40), const ui.Offset(80, 40)],
        16,
        clip: session.selectionClip,
      ),
    );
    session.applyErase();
    session.setCrop(session.initialCrop);
    await expectPixels(
      width: 120,
      height: 80,
      alpha: {const ui.Offset(45, 40): 255, const ui.Offset(70, 40): 0},
    );
  });

  test('pending strokes are retained but excluded from export', () async {
    session.addSelection(EraseStroke([const ui.Offset(20, 20)], 12));
    expect(await session.exportImage(), 'not-read.png');
    await expectPixels(
      width: 120,
      height: 80,
      alpha: {const ui.Offset(20, 20): 255},
    );
    expect(session.erase.pending, hasLength(1));
    session.applyErase();
    await expectPixels(
      width: 120,
      height: 80,
      alpha: {const ui.Offset(20, 20): 0},
    );
  });

  test('late decoding is disposed after editor closes', () async {
    final completer = Completer<ui.Image>();
    final closing = EditSession(
      'late.png',
      imageLoader: (_) => completer.future,
    );
    final loaded = original.clone();
    closing.dispose();
    completer.complete(loaded);
    await closing.ready;
    expect(loaded.debugDisposed, isTrue);
    expect(closing.image, isNull);
  });

  test('load errors cannot silently export an unreadable original', () async {
    final failed = EditSession(
      'missing.png',
      imageLoader: (_) async => throw StateError('missing'),
    );
    await failed.ready;
    expect(failed.error, isNotNull);
    await expectLater(failed.exportImage(), throwsStateError);
    failed.dispose();
  });
}
