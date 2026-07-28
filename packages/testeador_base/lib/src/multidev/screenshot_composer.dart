import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// {@template screenshot_composer}
/// Lays N device screenshots side-by-side into one PNG.
///
/// The composite is the artifact AI agents and human reviewers actually open
/// to decide whether a multi-device step looked right. Per-device PNGs are the
/// source; the composite is the summary.
/// {@endtemplate}
abstract class ScreenshotComposer {
  /// Lays [shots] out horizontally into one PNG written to [output].
  ///
  /// Rules:
  ///  - All shots scaled to the smallest height in the set (preserves aspect
  ///    ratio, avoids upscaling).
  ///  - Optional [labels] render in a header strip above each column.
  ///  - Column order matches the input order (deterministic for diffs in CI).
  static Future<File> sideBySide(
    List<File> shots, {
    required File output,
    List<String>? labels,
    int gapPx = 16,
    int headerHeightPx = 48,
    int background = 0xFF101418,
    int headerText = 0xFFE8ECF1,
  }) async {
    if (shots.isEmpty) {
      throw ArgumentError('Need at least one shot to compose.');
    }
    if (labels != null && labels.length != shots.length) {
      throw ArgumentError(
        'labels length (${labels.length}) must match shots length '
        '(${shots.length}).',
      );
    }

    final decoded = shots
        .map((f) => img.decodePng(f.readAsBytesSync())!)
        .toList(growable: false);
    final targetH = decoded.map((i) => i.height).reduce(math.min);
    final scaled = decoded.map((i) {
      return i.height == targetH ? i : img.copyResize(i, height: targetH);
    }).toList(growable: false);

    final totalW = scaled.fold<int>(0, (s, i) => s + i.width) +
        gapPx * (scaled.length - 1);
    final showHeader = labels != null;
    final canvasH = targetH + (showHeader ? headerHeightPx : 0);

    final canvas = img.Image(width: totalW, height: canvasH);
    img.fill(canvas, color: _rgb(background));

    final headerColor = _rgb(headerText);

    var x = 0;
    for (var k = 0; k < scaled.length; k++) {
      if (showHeader) {
        img.drawString(
          canvas,
          labels[k],
          font: img.arial24,
          x: x + 12,
          y: (headerHeightPx - 24) ~/ 2,
          color: headerColor,
        );
      }
      img.compositeImage(
        canvas,
        scaled[k],
        dstX: x,
        dstY: showHeader ? headerHeightPx : 0,
      );
      x += scaled[k].width + gapPx;
    }

    await output.parent.create(recursive: true);
    await output.writeAsBytes(img.encodePng(canvas));
    return output;
  }

  static img.ColorRgb8 _rgb(int hex) => img.ColorRgb8(
        (hex >> 16) & 0xFF,
        (hex >> 8) & 0xFF,
        hex & 0xFF,
      );
}
