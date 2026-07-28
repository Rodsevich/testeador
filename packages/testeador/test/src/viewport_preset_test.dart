import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:testeador/testeador.dart';

void main() {
  group('ViewportPreset', () {
    test('phone is a vertical phone at DPR 2', () {
      expect(ViewportPreset.phone.logicalSize, const Size(410, 890));
      expect(ViewportPreset.phone.devicePixelRatio, 2);
      expect(ViewportPreset.phone.physicalSize, const Size(820, 1780));
    });

    test('tablet is a vertical tablet at DPR 2', () {
      expect(ViewportPreset.tablet.logicalSize, const Size(800, 1280));
      expect(ViewportPreset.tablet.devicePixelRatio, 2);
      expect(ViewportPreset.tablet.physicalSize, const Size(1600, 2560));
    });
  });
}
