// Golden file test for ScreenshotComposer.sideBySide.
//
// Generates two synthetic input PNGs (small solid colors) and composes them.
// The resulting bytes are compared against a committed golden PNG so we catch
// any regression in the composer's output that wouldn't be obvious from a
// pixel-spot test (e.g. font subtly changing, gap rounding differing).
//
// To regenerate the golden after an INTENTIONAL change:
//
//     UPDATE_GOLDENS=1 dart test test/multidev/screenshot_composer_golden_test.dart
//
// Then `git diff` the new golden visually before committing.

import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';
import 'package:testeador/testeador.dart';

const _goldenPath = 'test/multidev/goldens/composite_two_devices.png';

void main() {
  test(
    'ScreenshotComposer.sideBySide matches committed golden',
    () async {
      final tempDir =
          await Directory.systemTemp.createTemp('composer_golden_');
      addTearDown(() async {
        if (tempDir.existsSync()) await tempDir.delete(recursive: true);
      });

      final shotRed = await _writeSolidPng(
        tempDir,
        'red.png',
        width: 200,
        height: 320,
        hex: 0xFFCC2233,
      );
      final shotBlue = await _writeSolidPng(
        tempDir,
        'blue.png',
        width: 200,
        height: 320,
        hex: 0xFF2233CC,
      );

      final actualOut = File('${tempDir.path}/actual.png');
      await ScreenshotComposer.sideBySide(
        [shotRed, shotBlue],
        output: actualOut,
        labels: const ['android · emu-A', 'ios · emu-B'],
      );
      final actual = actualOut.readAsBytesSync();

      final goldenFile = File(_goldenPath);
      if (Platform.environment['UPDATE_GOLDENS'] == '1' ||
          !goldenFile.existsSync()) {
        goldenFile.parent.createSync(recursive: true);
        goldenFile.writeAsBytesSync(actual);
        markTestSkipped(
          'Golden regenerated at $_goldenPath. Inspect the diff and re-run.',
        );
        return;
      }

      final expected = goldenFile.readAsBytesSync();
      expect(
        actual,
        equals(expected),
        reason:
            'Composite bytes diverged from $_goldenPath. If the change is '
            'intentional, re-run with UPDATE_GOLDENS=1 and review the diff.',
      );
    },
  );
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
