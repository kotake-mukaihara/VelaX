import 'dart:math' as math;
import 'dart:ui';

/// All editing coordinates are independent of the preview's size, in source
/// pixel units. Only the camera changes when a selection is enlarged on screen.
class CropState {
  const CropState({
    required this.crop,
    this.offset = Offset.zero,
    this.scale = 1,
    this.quarterTurns = 0,
    this.tilt = 0,
    this.mirrored = false,
    this.ratio = '自由',
  });

  factory CropState.initial(Size image) => CropState(
    crop: Rect.fromCenter(
      center: Offset.zero,
      width: image.width,
      height: image.height,
    ),
  );

  final Rect crop;
  final Offset offset;
  final double scale;
  final int quarterTurns;
  final double tilt;
  final bool mirrored;
  final String ratio;
  double get angle => quarterTurns * math.pi / 2 + tilt * math.pi / 180;

  CropState copyWith({
    Rect? crop,
    Offset? offset,
    double? scale,
    int? quarterTurns,
    double? tilt,
    bool? mirrored,
    String? ratio,
  }) => CropState(
    crop: crop ?? this.crop,
    offset: offset ?? this.offset,
    scale: scale ?? this.scale,
    quarterTurns: quarterTurns ?? this.quarterTurns,
    tilt: tilt ?? this.tilt,
    mirrored: mirrored ?? this.mirrored,
    ratio: ratio ?? this.ratio,
  );

  bool sameAs(CropState other) =>
      (crop.topLeft - other.crop.topLeft).distance < 0.0001 &&
      (crop.bottomRight - other.crop.bottomRight).distance < 0.0001 &&
      (offset - other.offset).distance < 0.0001 &&
      (scale - other.scale).abs() < 0.000001 &&
      quarterTurns % 4 == other.quarterTurns % 4 &&
      (tilt - other.tilt).abs() < 0.000001 &&
      mirrored == other.mirrored &&
      ratio == other.ratio;
}

Offset rotatePoint(Offset point, double angle) => Offset(
  point.dx * math.cos(angle) - point.dy * math.sin(angle),
  point.dx * math.sin(angle) + point.dy * math.cos(angle),
);

List<Offset> cropCorners(Rect rect) => [
  rect.topLeft,
  rect.topRight,
  rect.bottomRight,
  rect.bottomLeft,
];

/// The crop's bounds in the image's rotated axes. Mirroring does not change
/// these bounds because the source rectangle is centered on its origin.
Rect _localBounds(CropState state) {
  final points = cropCorners(state.crop)
      .map((p) => rotatePoint(p, -state.angle));
  return Rect.fromLTRB(
    points.map((p) => p.dx).reduce(math.min),
    points.map((p) => p.dy).reduce(math.min),
    points.map((p) => p.dx).reduce(math.max),
    points.map((p) => p.dy).reduce(math.max),
  );
}

bool cropIsCovered(CropState state, Size image) {
  final bounds = _localBounds(state)
      .shift(-rotatePoint(state.offset, -state.angle));
  final halfWidth = image.width * state.scale / 2 + 0.00001;
  final halfHeight = image.height * state.scale / 2 + 0.00001;
  return bounds.left >= -halfWidth &&
      bounds.right <= halfWidth &&
      bounds.top >= -halfHeight &&
      bounds.bottom <= halfHeight;
}

/// Project the image center onto the nearest valid position. This operates in
/// image axes, so even at 45 degrees no empty triangles enter the selection.
CropState coverCrop(CropState state, Size image) {
  final bounds = _localBounds(state);
  final scale = math.max(
    state.scale,
    math.max(bounds.width / image.width, bounds.height / image.height),
  );
  final center = rotatePoint(state.offset, -state.angle);
  final halfWidth = image.width * scale / 2;
  final halfHeight = image.height * scale / 2;
  // max handles sub-pixel rounding when the valid interval has zero length.
  final minX = bounds.right - halfWidth;
  final minY = bounds.bottom - halfHeight;
  final next = Offset(
    center.dx.clamp(minX, math.max(minX, bounds.left + halfWidth)),
    center.dy.clamp(minY, math.max(minY, bounds.top + halfHeight)),
  );
  return state.copyWith(scale: scale, offset: rotatePoint(next, state.angle));
}

const cropRatios = <String, double?>{
  '自由': null,
  '原始': null,
  '1:1': 1,
  '3:4': 3 / 4,
  '4:3': 4 / 3,
  '9:16': 9 / 16,
  '16:9': 16 / 9,
  '2:3': 2 / 3,
  '3:2': 3 / 2,
  '5:7': 5 / 7,
  '7:5': 7 / 5,
};

double? selectedRatio(CropState state, Size image) => state.ratio == '原始'
    ? (state.quarterTurns.isEven
          ? image.width / image.height
          : image.height / image.width)
    : cropRatios[state.ratio];

CropState selectCropRatio(CropState state, String label, Size image) {
  final next = state.copyWith(ratio: label);
  final ratio = selectedRatio(next, image);
  if (ratio == null) return next;
  final width = math.min(state.crop.width, state.crop.height * ratio);
  return next.copyWith(
    crop: Rect.fromCenter(
      center: state.crop.center,
      width: width,
      height: width / ratio,
    ),
  );
}

/// Eight handles, clockwise from the upper left. Side handles in fixed-ratio
/// mode resize the other dimension symmetrically, keeping the opposite side.
Rect resizeCrop(
  CropState state,
  Size image,
  int handle,
  Offset delta,
  double minimum,
) {
  final r = state.crop;
  final left = [0, 6, 7].contains(handle);
  final right = [2, 3, 4].contains(handle);
  final top = [0, 1, 2].contains(handle);
  final bottom = [4, 5, 6].contains(handle);
  var width = math.max(
    minimum,
    r.width +
        (left
            ? -delta.dx
            : right
            ? delta.dx
            : 0),
  );
  var height = math.max(
    minimum,
    r.height +
        (top
            ? -delta.dy
            : bottom
            ? delta.dy
            : 0),
  );
  final ratio = selectedRatio(state, image);
  if (ratio != null) {
    if (!(left || right)) {
      width = height * ratio;
    } else if (!(top || bottom)) {
      height = width / ratio;
    } else {
      // Project a diagonal drag onto the aspect-ratio line.
      height = (width * ratio + height) / (ratio * ratio + 1);
      width = height * ratio;
    }
    final factor = math.max(1.0, math.max(minimum / width, minimum / height));
    width *= factor;
    height *= factor;
  }
  final x = left
      ? r.right - width
      : right
      ? r.left
      : r.center.dx - width / 2;
  final y = top
      ? r.bottom - height
      : bottom
      ? r.top
      : r.center.dy - height / 2;
  final candidate = Rect.fromLTWH(x, y, width, height);
  if (cropIsCovered(state.copyWith(crop: candidate), image)) return candidate;
  // Both coverage and ratio constraints are convex along this drag segment.
  var low = 0.0;
  var high = 1.0;
  for (var i = 0; i < 40; i++) {
    final mid = (low + high) / 2;
    if (cropIsCovered(
      state.copyWith(crop: Rect.lerp(r, candidate, mid)!),
      image,
    )) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return Rect.lerp(r, candidate, low)!;
}

CropState rotateCropLeft(CropState state, Size image) {
  final center = state.crop.center;
  final flexible = state.ratio == '自由' || state.ratio == '原始';
  return coverCrop(
    state.copyWith(
      quarterTurns: (state.quarterTurns - 1) % 4,
      offset: center + rotatePoint(state.offset - center, -math.pi / 2),
      crop: flexible
          ? Rect.fromCenter(
              center: center,
              width: state.crop.height,
              height: state.crop.width,
            )
          : state.crop,
    ),
    image,
  );
}

/// Reflect in screen space, including after arbitrary rotation.
CropState mirrorCrop(CropState state) => state.copyWith(
  offset: Offset(2 * state.crop.center.dx - state.offset.dx, state.offset.dy),
  quarterTurns: (-state.quarterTurns) % 4,
  tilt: -state.tilt,
  mirrored: !state.mirrored,
);
