import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:velax/features/wardrobe/crop_geometry.dart';
import 'package:velax/features/wardrobe/crop_image_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const imageSize = Size(600, 400);

  test('eight handles respect rotated image bounds and all locked ratios', () {
    final random = math.Random(231);
    for (final label in cropRatios.keys) {
      for (final tilt in [-45.0, -17.0, 0.0, 21.0, 45.0]) {
        var state = coverCrop(
          CropState.initial(imageSize).copyWith(tilt: tilt),
          imageSize,
        );
        state = selectCropRatio(state, label, imageSize);
        for (var handle = 0; handle < 8; handle++) {
          for (var attempt = 0; attempt < 25; attempt++) {
            final rect = resizeCrop(
              state,
              imageSize,
              handle,
              Offset(
                random.nextDouble() * 1800 - 900,
                random.nextDouble() * 1800 - 900,
              ),
              20,
            );
            expect(
              cropIsCovered(state.copyWith(crop: rect), imageSize),
              isTrue,
              reason: '$label / $tilt / $handle',
            );
            expect(rect.shortestSide, greaterThanOrEqualTo(19.99));
            final ratio = selectedRatio(state, imageSize);
            if (ratio != null) {
              expect(rect.width / rect.height, closeTo(ratio, 0.000001));
            }
          }
        }
      }
    }
  });

  test('pan correction is nearest legal position and idempotent', () {
    final initial = CropState.initial(imageSize);
    final cropped = initial.copyWith(
      crop: const Rect.fromLTWH(-100, -80, 200, 160),
    );
    final moved = coverCrop(
      cropped.copyWith(offset: const Offset(1000, -1000)),
      imageSize,
    );
    expect(moved.offset, const Offset(200, -120));
    for (var angle = -45.0; angle <= 45; angle += 5) {
      final result = coverCrop(
        cropped.copyWith(tilt: angle, offset: const Offset(1000, -1000)),
        imageSize,
      );
      expect(cropIsCovered(result, imageSize), isTrue);
      expect(coverCrop(result, imageSize).sameAs(result), isTrue);
    }
  });

  test('quarter turns and screen-horizontal mirroring preserve coverage', () {
    var state = CropState.initial(imageSize);
    final initial = state;
    for (var i = 0; i < 4; i++) {
      state = rotateCropLeft(state, imageSize);
      expect(cropIsCovered(state, imageSize), isTrue);
    }
    expect(state.sameAs(initial), isTrue);
    state = coverCrop(
      selectCropRatio(
        initial,
        '3:4',
        imageSize,
      ).copyWith(tilt: 32, offset: const Offset(60, -20)),
      imageSize,
    );
    expect(cropIsCovered(mirrorCrop(state), imageSize), isTrue);
    expect(mirrorCrop(mirrorCrop(state)).sameAs(state), isTrue);
    expect(
      rotateCropLeft(state, imageSize).crop.width / state.crop.height,
      closeTo(3 / 4, 0.000001),
    );
  });

  test(
    'export rotates and mirrors the actual pixels, preserving alpha',
    () async {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 20, 20),
        Paint()..color = const Color(0xFFFF0000),
      );
      canvas.drawRect(
        const Rect.fromLTWH(20, 0, 20, 20),
        Paint()..color = const Color(0xFF00FF00),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 20, 20, 20),
        Paint()..color = const Color(0xFF0000FF),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(40, 40);
      picture.dispose();
      addTearDown(image.dispose);
      const size = Size(40, 40);
      final initial = CropState.initial(size);

      Future<List<int>> pixel(
        CropState state,
        int x,
        int y, {
        int width = 40,
        int height = 40,
      }) async {
        final codec = await instantiateImageCodec(
          await renderCrop(image, state),
        );
        final output = (await codec.getNextFrame()).image;
        codec.dispose();
        expect(output.width, width);
        expect(output.height, height);
        final bytes = (await output.toByteData())!.buffer.asUint8List();
        final color = bytes.sublist(
          (y * width + x) * 4,
          (y * width + x) * 4 + 4,
        );
        output.dispose();
        return color;
      }

      expect(await pixel(initial, 5, 5), [255, 0, 0, 255]);
      expect(await pixel(initial, 30, 30), [0, 0, 0, 0]);
      expect(await pixel(mirrorCrop(initial), 5, 5), [0, 255, 0, 255]);
      expect(await pixel(rotateCropLeft(initial, size), 5, 5), [
        0,
        255,
        0,
        255,
      ]);
      expect(await pixel(mirrorCrop(rotateCropLeft(initial, size)), 5, 5), [
        0,
        0,
        0,
        0,
      ]);
      expect(
        await pixel(
          initial.copyWith(crop: const Rect.fromLTWH(-20, 0, 20, 20)),
          5,
          5,
          width: 20,
          height: 20,
        ),
        [0, 0, 255, 255],
      );
    },
  );
}
