import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:testeador/testeador.dart';

void main() {
  group('ScreenshotComposer.sideBySide', () {
    late Directory tempDir;
    late File shotRed;
    late File shotBlue;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('composer_test_');
      shotRed = await _writeSolidPng(
        tempDir,
        'red.png',
        width: 200,
        height: 400,
        hex: 0xFFCC2233,
      );
      shotBlue = await _writeSolidPng(
        tempDir,
        'blue.png',
        width: 220,
        height: 400,
        hex: 0xFF2233CC,
      );
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test('throws when shots is empty', () async {
      expect(
        () => ScreenshotComposer.sideBySide(
          [],
          output: File('${tempDir.path}/out.png'),
        ),
        throwsArgumentError,
      );
    });

    test('throws when labels length mismatches shots', () async {
      expect(
        () => ScreenshotComposer.sideBySide(
          [shotRed, shotBlue],
          output: File('${tempDir.path}/out.png'),
          labels: const ['only one'],
        ),
        throwsArgumentError,
      );
    });

    test('lays two equal-height shots side by side with header strip',
        () async {
      final out = File('${tempDir.path}/two.png');
      await ScreenshotComposer.sideBySide(
        [shotRed, shotBlue],
        output: out,
        labels: const ['android · emu-A', 'ios · emu-B'],
        // explicit defaults for clarity
      );
      expect(out.existsSync(), isTrue);

      final composed = img.decodePng(out.readAsBytesSync())!;
      // Canvas width = sum of input widths + gap between columns.
      expect(composed.width, equals(200 + 220 + 16));
      // Canvas height = column height + header strip.
      expect(composed.height, equals(400 + 48));

      // First column body should be the red shot color (well inside it).
      expect(_pixelHex(composed, x: 100, y: 200), equals(0xFFCC2233));
      // Second column body should be the blue shot color.
      expect(_pixelHex(composed, x: 200 + 16 + 110, y: 200),
          equals(0xFF2233CC));
      // The 16 px gap between the columns must be background.
      expect(_pixelHex(composed, x: 200 + 8, y: 200), equals(0xFF101418));
      // Header strip (above the column bodies) is background.
      expect(_pixelHex(composed, x: 1, y: 1), equals(0xFF101418));
    });

    test('omits the header strip when no labels are provided', () async {
      final out = File('${tempDir.path}/no_header.png');
      await ScreenshotComposer.sideBySide(
        [shotRed, shotBlue],
        output: out,
      );
      final composed = img.decodePng(out.readAsBytesSync())!;
      // No header → height equals the shot height.
      expect(composed.height, equals(400));
      // First pixel is inside the red shot, not background.
      expect(_pixelHex(composed, x: 1, y: 1), equals(0xFFCC2233));
    });

    test('byte-stable output for identical input (golden hash)', () async {
      final out1 = File('${tempDir.path}/stable_1.png');
      final out2 = File('${tempDir.path}/stable_2.png');
      await ScreenshotComposer.sideBySide(
        [shotRed, shotBlue],
        output: out1,
        labels: const ['a', 'b'],
      );
      await ScreenshotComposer.sideBySide(
        [shotRed, shotBlue],
        output: out2,
        labels: const ['a', 'b'],
      );
      expect(out1.readAsBytesSync(), equals(out2.readAsBytesSync()));
    });

    test('scales unequal heights to the smaller height (preserve aspect)',
        () async {
      final shotTall = await _writeSolidPng(
        tempDir,
        'tall.png',
        width: 200,
        height: 600,
        hex: 0xFF00AA00,
      );
      final out = File('${tempDir.path}/scaled.png');
      await ScreenshotComposer.sideBySide(
        [shotRed, shotTall],
        output: out,
      );
      final composed = img.decodePng(out.readAsBytesSync())!;
      // No header (no labels) → height = min(400, 600) = 400.
      expect(composed.height, equals(400));
      // Tall shot 200×600 scaled to height 400 → width 200 * 400/600 ≈ 133.
      const expectedScaledWidth = 133;
      expect(
        composed.width,
        anyOf(
          equals(200 + 16 + expectedScaledWidth),
          equals(200 + 16 + expectedScaledWidth - 1),
          equals(200 + 16 + expectedScaledWidth + 1),
        ),
        reason: 'Scaled width tolerates ±1 px rounding noise.',
      );
    });

    test('column order matches input order (determinism for CI diffs)',
        () async {
      final outAB = File('${tempDir.path}/ab.png');
      final outBA = File('${tempDir.path}/ba.png');
      await ScreenshotComposer.sideBySide(
        [shotRed, shotBlue],
        output: outAB,
      );
      await ScreenshotComposer.sideBySide(
        [shotBlue, shotRed],
        output: outBA,
      );
      final ab = img.decodePng(outAB.readAsBytesSync())!;
      final ba = img.decodePng(outBA.readAsBytesSync())!;
      // AB: red on the left, blue on the right.
      expect(_pixelHex(ab, x: 100, y: 200), equals(0xFFCC2233));
      // BA: blue on the left, red on the right.
      expect(_pixelHex(ba, x: 100, y: 200), equals(0xFF2233CC));
      // Both have the same dimensions (same input set).
      expect(ab.width, equals(ba.width));
      expect(ab.height, equals(ba.height));
    });
  });
}

Future<File> _writeSolidPng(
  Directory dir,
  String name, {
  required int width,
  required int height,
  required int hex,
}) async {
  final image = img.Image(width: width, height: height);
  img.fill(
    image,
    color: img.ColorRgb8(
      (hex >> 16) & 0xFF,
      (hex >> 8) & 0xFF,
      hex & 0xFF,
    ),
  );
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(img.encodePng(image));
  return file;
}

int _pixelHex(img.Image image, {required int x, required int y}) {
  final p = image.getPixel(x, y);
  return (0xFF << 24) |
      (p.r.toInt() << 16) |
      (p.g.toInt() << 8) |
      p.b.toInt();
}
