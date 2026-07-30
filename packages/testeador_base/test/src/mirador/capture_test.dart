import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:testeador_base/evidence.dart';
import 'package:testeador_base/mirador.dart';

/// Captura de laboratorio: escribe el PNG que se le diga, sin tocar adb. Lo
/// que se ejercita es el layout de evidencia y el scoring, no el transporte.
ScreenshotTaker _fake(List<int> bytes) => (out) async {
  out.parent.createSync(recursive: true);
  return out..writeAsBytesSync(bytes);
};

List<int> _png({int w = 60, int h = 60, int dirtyRows = 0}) {
  final im = img.Image(width: w, height: h);
  img.fill(im, color: img.ColorRgb8(240, 235, 220));
  for (var y = 0; y < dirtyRows; y++) {
    for (var x = 0; x < w; x++) {
      im.setPixelRgba(x, h - 1 - y, 217, 45, 32, 255);
    }
  }
  return img.encodePng(im);
}

void main() {
  late Directory tmp;
  late String base;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mirador_capture');
    base = p.join(tmp.path, 'test_evidence');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Map<String, Object?> manifestOf(String scenario, String actor) =>
      jsonDecode(
            File(
              p.join(
                scenarioRunDir(baseDir: base, scenario: scenario),
                '$actor.manifest.json',
              ),
            ).readAsStringSync(),
          )
          as Map<String, Object?>;

  test(
    'primera captura: ~new, sin diff, y el manifest la marca origin live',
    () async {
      final r = await captureLive(
        take: _fake(_png()),
        baseDir: base,
        scenario: 'en vivo',
        actor: 'converso',
        slug: 'hodie',
        intent: 'el plan del día se ve completo',
      );

      expect(r.isNew, isTrue);
      expect(r.marks, 0);
      expect(File(r.capture).existsSync(), isTrue);
      expect(p.basename(r.capture), 'converso-01_hodie~new.png');

      final step =
          (manifestOf('en_vivo', 'converso')['steps']! as List).single
              as Map<String, Object?>;
      expect(step['intent'], 'el plan del día se ve completo');
      expect(
        step['origin'],
        'live',
        reason:
            'no se mezcla con la evidencia rasterizada: el screenshot del '
            'device incluye la barra de estado del sistema',
      );
    },
  );

  test('con baseline, la captura se puntúa y escribe su tríptico', () async {
    await captureLive(
      take: _fake(_png()),
      baseDir: base,
      scenario: 'en vivo',
      actor: 'converso',
      slug: 'hodie',
    );
    promoteToBaseline(
      baseDir: base,
      scenario: 'en vivo',
      actor: 'converso',
      slugs: const ['hodie'],
    );

    // 60×60 = 3600 px; 18 filas = 30%.
    final r = await captureLive(
      take: _fake(_png(dirtyRows: 18)),
      baseDir: base,
      scenario: 'en vivo',
      actor: 'converso',
      slug: 'hodie',
    );

    expect(r.isNew, isFalse);
    expect(r.marks, 4, reason: '30% de drift son cuatro marcas');
    expect(r.ratio, closeTo(0.30, 0.01));

    final runDir = scenarioRunDir(baseDir: base, scenario: 'en_vivo');
    expect(
      File(p.join(runDir, 'converso-01_hodie!!!!.diff.png')).existsSync(),
      isTrue,
    );
  });

  test('sin drift no hay tríptico y la captura queda sin marcas', () async {
    await captureLive(
      take: _fake(_png()),
      baseDir: base,
      scenario: 'en vivo',
      actor: 'converso',
      slug: 'hodie',
    );
    promoteToBaseline(
      baseDir: base,
      scenario: 'en vivo',
      actor: 'converso',
      slugs: const ['hodie'],
    );

    final r = await captureLive(
      take: _fake(_png()),
      baseDir: base,
      scenario: 'en vivo',
      actor: 'converso',
      slug: 'hodie',
    );
    expect(r.marks, 0);

    final runDir = scenarioRunDir(baseDir: base, scenario: 'en_vivo');
    expect(
      Directory(runDir)
          .listSync()
          .map((f) => p.basename(f.path))
          .where((n) => n.endsWith('.diff.png')),
      isEmpty,
    );
  });

  test('un screenshot que no es PNG falla con un mensaje accionable', () async {
    await expectLater(
      () => captureLive(
        take: _fake(const [1, 2, 3]),
        source: 'fake-1',
        baseDir: base,
        scenario: 'en vivo',
        actor: 'converso',
        slug: 'hodie',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('no es un PNG'), contains('fake-1')),
        ),
      ),
    );
  });
}
