import 'package:test/test.dart';
import 'package:image/image.dart' as img;
import 'package:testeador_base/evidence.dart';

/// Builds a solid white image and repaints exactly [changedPixels] of them
/// black, scanning row by row.
img.Image _withChangedPixels(int width, int height, int changedPixels) {
  final image = img.Image(width: width, height: height)
    ..clear(img.ColorRgb8(255, 255, 255));
  var remaining = changedPixels;
  for (var y = 0; y < height && remaining > 0; y++) {
    for (var x = 0; x < width && remaining > 0; x++) {
      image.setPixel(x, y, img.ColorRgb8(0, 0, 0));
      remaining--;
    }
  }
  return image;
}

void main() {
  const noiseFloor = 0.0001; // 0.01%
  const maxMarks = 5;
  const tolerance = 8;

  img.Image white(int w, int h) =>
      img.Image(width: w, height: h)..clear(img.ColorRgb8(255, 255, 255));

  group('marksFor — log10 calibration (floor 0.01%, max 5)', () {
    test('0% → 0 marks', () {
      expect(marksFor(0, noiseFloor: noiseFloor, maxMarks: maxMarks), 0);
    });

    test('0.005% (below floor) → 0 marks', () {
      expect(marksFor(0.00005, noiseFloor: noiseFloor, maxMarks: maxMarks), 0);
    });

    test('0.1% → 1 mark (boundary belongs to the lower bucket)', () {
      expect(marksFor(0.001, noiseFloor: noiseFloor, maxMarks: maxMarks), 1);
    });

    test('1% → 2 marks', () {
      expect(marksFor(0.01, noiseFloor: noiseFloor, maxMarks: maxMarks), 2);
    });

    test('10% → 3 marks', () {
      expect(marksFor(0.1, noiseFloor: noiseFloor, maxMarks: maxMarks), 3);
    });

    test('20% → 4 marks', () {
      expect(marksFor(0.2, noiseFloor: noiseFloor, maxMarks: maxMarks), 4);
    });

    test('100% → 5 marks (≥50% saturates to max)', () {
      expect(marksFor(1, noiseFloor: noiseFloor, maxMarks: maxMarks), 5);
      expect(marksFor(0.5, noiseFloor: noiseFloor, maxMarks: maxMarks), 5);
    });

    test('exactly the floor → 1 mark', () {
      expect(
        marksFor(noiseFloor, noiseFloor: noiseFloor, maxMarks: maxMarks),
        1,
      );
    });

    test('degenerate scales (maxMarks ≤ 1) never throw', () {
      // Any drift above the floor saturates immediately.
      expect(marksFor(0.001, noiseFloor: noiseFloor, maxMarks: 1), 1);
      expect(marksFor(0.9, noiseFloor: noiseFloor, maxMarks: 1), 1);
      expect(marksFor(0.001, noiseFloor: noiseFloor, maxMarks: 0), 0);
      expect(marksFor(0, noiseFloor: noiseFloor, maxMarks: 1), 0);
      // maxMarks 2: floor bucket and saturation, no intermediate crash.
      expect(marksFor(0.001, noiseFloor: noiseFloor, maxMarks: 2), 1);
      expect(marksFor(0.6, noiseFloor: noiseFloor, maxMarks: 2), 2);
    });
  });

  group('diffScore', () {
    test('identical images → ratio 0, 0 marks', () {
      final result = diffScore(
        actual: white(100, 100),
        baseline: white(100, 100),
        noiseFloor: noiseFloor,
        maxMarks: maxMarks,
        channelTolerance: tolerance,
      );
      expect(result.ratio, 0);
      expect(result.marks, 0);
      expect(result.dimensionMismatch, isFalse);
    });

    test('sub-tolerance channel deltas count as identical', () {
      final almostWhite = img.Image(width: 50, height: 50)
        ..clear(img.ColorRgb8(250, 252, 255));
      final result = diffScore(
        actual: almostWhite,
        baseline: white(50, 50),
        noiseFloor: noiseFloor,
        maxMarks: maxMarks,
        channelTolerance: tolerance,
      );
      expect(result.ratio, 0);
      expect(result.marks, 0);
    });

    test('scores exact changed-pixel ratios on a 1000×1000 image', () {
      final baseline = white(1000, 1000);
      // 1000 changed pixels of 1M = 0.1% → 1 mark.
      final punctual = diffScore(
        actual: _withChangedPixels(1000, 1000, 1000),
        baseline: baseline,
        noiseFloor: noiseFloor,
        maxMarks: maxMarks,
        channelTolerance: tolerance,
      );
      expect(punctual.ratio, closeTo(0.001, 1e-9));
      expect(punctual.marks, 1);

      // 100k changed pixels = 10% → 3 marks.
      final section = diffScore(
        actual: _withChangedPixels(1000, 1000, 100000),
        baseline: baseline,
        noiseFloor: noiseFloor,
        maxMarks: maxMarks,
        channelTolerance: tolerance,
      );
      expect(section.ratio, closeTo(0.1, 1e-9));
      expect(section.marks, 3);
    });

    test('everything changed → 5 marks', () {
      final black = img.Image(width: 100, height: 100)
        ..clear(img.ColorRgb8(0, 0, 0));
      final result = diffScore(
        actual: black,
        baseline: white(100, 100),
        noiseFloor: noiseFloor,
        maxMarks: maxMarks,
        channelTolerance: tolerance,
      );
      expect(result.ratio, 1);
      expect(result.marks, 5);
    });

    test('dimension mismatch → max marks + flag, no comparison', () {
      final result = diffScore(
        actual: white(100, 100),
        baseline: white(200, 200),
        noiseFloor: noiseFloor,
        maxMarks: maxMarks,
        channelTolerance: tolerance,
      );
      expect(result.dimensionMismatch, isTrue);
      expect(result.ratio, 1);
      expect(result.marks, maxMarks);
    });
  });

  group('composeDiffImage', () {
    test('canvas is three panels wide plus gutters', () {
      final triptych = composeDiffImage(
        baseline: white(100, 80),
        actual: white(100, 80),
        channelTolerance: tolerance,
      );
      expect(triptych.width, 100 * 3 + 4 * 2);
      expect(triptych.height, 80);
    });

    test('changed pixels are magenta in the diff panel', () {
      final baseline = white(10, 10);
      final actual = _withChangedPixels(10, 10, 1); // pixel (0,0) black
      final triptych = composeDiffImage(
        baseline: baseline,
        actual: actual,
        channelTolerance: tolerance,
      );
      const diffPanelX = (10 + 4) * 2;
      final changed = triptych.getPixel(diffPanelX, 0);
      expect(changed.r, 255);
      expect(changed.g, 0);
      expect(changed.b, 255);
      // An unchanged pixel in the diff panel is dimmed grayscale, not magenta.
      final unchanged = triptych.getPixel(diffPanelX + 5, 5);
      expect(unchanged.r, equals(unchanged.g));
      expect(unchanged.g, equals(unchanged.b));
    });

    test('left and middle panels are verbatim copies', () {
      final baseline = white(10, 10);
      final actual = _withChangedPixels(10, 10, 1);
      final triptych = composeDiffImage(
        baseline: baseline,
        actual: actual,
        channelTolerance: tolerance,
      );
      expect(triptych.getPixel(0, 0).r, 255); // baseline panel: white
      expect(triptych.getPixel(10 + 4, 0).r, 0); // actual panel: black pixel
    });
  });
}
