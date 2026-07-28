/// Pure pixel-diff scoring and diff-image composition.
///
/// The differ is a *scorer*, not a gate: it never fails a test. Its output
/// feeds the `!` drift markers on artifact file names and the run manifest.
library;

import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Result of scoring a capture against its baseline.
///
/// - `ratio` — fraction of pixels that differ beyond the per-channel
///   tolerance (`1.0` when dimensions mismatch).
/// - `marks` — number of `!` markers derived from `ratio` (see [marksFor]).
/// - `dimensionMismatch` — `true` when the two images have different sizes,
///   in which case no pixel comparison is possible and `marks` is the
///   configured maximum.
typedef DiffResult = ({double ratio, int marks, bool dimensionMismatch});

/// Maps a diff [ratio] to a number of `!` marks on a log10 scale.
///
/// Each additional mark means roughly *10× more drift*:
///
/// | ratio (noiseFloor = 0.01%) | marks | reading                    |
/// |----------------------------|-------|----------------------------|
/// | < 0.01%                    | 0     | noise / identical          |
/// | 0.01% – 0.1%               | 1     | punctual change (an icon)  |
/// | 0.1% – 1%                  | 2     | a component changed        |
/// | 1% – 10%                   | 3     | a section of the screen    |
/// | 10% – 50%                  | 4     | half the screen            |
/// | ≥ 50%                      | 5     | unrecognizable             |
int marksFor(
  double ratio, {
  required double noiseFloor,
  required int maxMarks,
}) {
  if (ratio < noiseFloor) return 0;
  // ≥50% saturates to the top; degenerate scales (maxMarks ≤ 1) have no
  // intermediate buckets, so any drift above the floor is already the top.
  if (ratio >= 0.5 || maxMarks <= 1) return maxMarks;
  final decades = (math.log(ratio / noiseFloor) / math.ln10).ceil();
  return decades.clamp(1, maxMarks - 1);
}

/// Scores [actual] against [baseline].
///
/// A pixel counts as different when any RGBA channel differs by more than
/// [channelTolerance] (0–255). Images of different dimensions cannot be
/// compared pixel-wise: the result is `ratio: 1.0`, `marks: maxMarks`,
/// `dimensionMismatch: true`.
DiffResult diffScore({
  required img.Image actual,
  required img.Image baseline,
  required double noiseFloor,
  required int maxMarks,
  required int channelTolerance,
}) {
  if (actual.width != baseline.width || actual.height != baseline.height) {
    return (ratio: 1.0, marks: maxMarks, dimensionMismatch: true);
  }
  var changed = 0;
  for (var y = 0; y < actual.height; y++) {
    for (var x = 0; x < actual.width; x++) {
      if (_pixelDiffers(
        actual.getPixel(x, y),
        baseline.getPixel(x, y),
        channelTolerance,
      )) {
        changed++;
      }
    }
  }
  final total = actual.width * actual.height;
  final ratio = total == 0 ? 0.0 : changed / total;
  return (
    ratio: ratio,
    marks: marksFor(ratio, noiseFloor: noiseFloor, maxMarks: maxMarks),
    dimensionMismatch: false,
  );
}

/// Composes the `baseline | actual | diff` triptych for human review.
///
/// The right panel shows the baseline dimmed to grayscale with every changed
/// pixel highlighted in magenta — the visual language of `flutter_test`'s
/// golden failure output. A thin white gutter separates the panels.
///
/// Only meaningful when both images share dimensions; callers skip triptych
/// generation on dimension mismatch.
img.Image composeDiffImage({
  required img.Image baseline,
  required img.Image actual,
  required int channelTolerance,
}) {
  const gutter = 4;
  final width = baseline.width * 3 + gutter * 2;
  final canvas = img.Image(width: width, height: baseline.height)
    ..clear(img.ColorRgb8(255, 255, 255));

  img.compositeImage(canvas, baseline);
  img.compositeImage(canvas, actual, dstX: baseline.width + gutter);

  final diffPanelX = (baseline.width + gutter) * 2;
  final magenta = img.ColorRgb8(255, 0, 255);
  for (var y = 0; y < baseline.height; y++) {
    for (var x = 0; x < baseline.width; x++) {
      final basePixel = baseline.getPixel(x, y);
      if (_pixelDiffers(actual.getPixel(x, y), basePixel, channelTolerance)) {
        canvas.setPixel(diffPanelX + x, y, magenta);
      } else {
        // Dimmed grayscale of the baseline: context without distraction.
        final luma = img.getLuminanceRgb(
          basePixel.r.toInt(),
          basePixel.g.toInt(),
          basePixel.b.toInt(),
        );
        final dimmed = 128 + luma ~/ 2;
        canvas.setPixel(
          diffPanelX + x,
          y,
          img.ColorRgb8(dimmed, dimmed, dimmed),
        );
      }
    }
  }
  return canvas;
}

bool _pixelDiffers(img.Pixel a, img.Pixel b, int tolerance) =>
    (a.r - b.r).abs() > tolerance ||
    (a.g - b.g).abs() > tolerance ||
    (a.b - b.b).abs() > tolerance ||
    (a.a - b.a).abs() > tolerance;
