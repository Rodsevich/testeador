import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:testeador_base/evidence.dart';
import 'package:testeador_base/mirador.dart';

/// PNG sólido de [w]×[h], con una banda inferior de [dirtyRows] en otro color
/// para producir drift medible.
List<int> _png({
  int w = 100,
  int h = 100,
  int dirtyRows = 0,
}) {
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
  late String src;
  late String base;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mirador_ingest');
    src = p.join(tmp.path, 'evidence', 'f9-flujo', 'android-emulator-5554');
    base = p.join(tmp.path, 'test_evidence');
    Directory(src).createSync(recursive: true);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  void shot(String name, {int dirtyRows = 0}) =>
      File(p.join(src, name)).writeAsBytesSync(_png(dirtyRows: dirtyRows));

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

  test('primera corrida: todo ~new, sin diff, y manifest completo', () {
    shot('01-hodie.png');
    shot('02-regula.png');

    final r = ingestPatrolRun(
      sourceDir: src,
      baseDir: base,
      scenario: 'f9-flujo',
      actor: 'novicio',
    );

    expect(r.captures, 2);
    expect(r.brandNew, 2);
    expect(r.drifted, 0);

    final runDir = scenarioRunDir(baseDir: base, scenario: 'f9_flujo');
    expect(
      File(p.join(runDir, 'novicio-01_hodie~new.png')).existsSync(),
      isTrue,
    );
    expect(
      File(p.join(runDir, 'novicio-02_regula~new.png')).existsSync(),
      isTrue,
    );

    final steps = manifestOf('f9_flujo', 'novicio')['steps']! as List<Object?>;
    expect(steps, hasLength(2));
    expect(
      (steps.first! as Map<String, Object?>)['origin'],
      'patrol',
      reason: 'la evidencia de device se marca como tal',
    );
  });

  test(
    'el pareo es por LABEL, no por el prefijo NN: si la numeración se corre '
    'entre corridas, el baseline sigue calzando',
    () {
      // Corrida 1: hodie es 01.
      shot('01-hodie.png');
      shot('02-regula.png');
      ingestPatrolRun(
        sourceDir: src,
        baseDir: base,
        scenario: 'f9-flujo',
        actor: 'novicio',
      );
      promoteToBaseline(
        baseDir: base,
        scenario: 'f9-flujo',
        actor: 'novicio',
        slugs: const ['hodie', 'regula'],
      );

      // Corrida 2: apareció una captura condicional antes, así que hodie pasó
      // a 02 y regula a 03 — exactamente lo que pasa con shots.dart.
      for (final f in Directory(src).listSync()) {
        f.deleteSync();
      }
      shot('01-onboarding.png');
      shot('02-hodie.png');
      shot('03-regula.png');

      final r = ingestPatrolRun(
        sourceDir: src,
        baseDir: base,
        scenario: 'f9-flujo',
        actor: 'novicio',
      );

      expect(r.captures, 3);
      expect(
        r.brandNew,
        1,
        reason:
            'solo onboarding es nueva; hodie y regula tienen baseline '
            'aunque su número cambió',
      );
      expect(r.drifted, 0, reason: 'el contenido no cambió');
    },
  );

  test('la magnitud del cambio determina las marcas del nombre', () {
    shot('01-quieta.png');
    shot('02-poquito.png');
    shot('03-bastante.png');
    ingestPatrolRun(
      sourceDir: src,
      baseDir: base,
      scenario: 'f9-flujo',
      actor: 'novicio',
    );
    promoteToBaseline(
      baseDir: base,
      scenario: 'f9-flujo',
      actor: 'novicio',
      slugs: const ['quieta', 'poquito', 'bastante'],
    );

    // 100×100 = 10 000 px. 1 fila = 1%; 30 filas = 30%.
    shot('01-quieta.png');
    shot('02-poquito.png', dirtyRows: 1);
    shot('03-bastante.png', dirtyRows: 30);

    final r = ingestPatrolRun(
      sourceDir: src,
      baseDir: base,
      scenario: 'f9-flujo',
      actor: 'novicio',
    );
    expect(r.drifted, 2);

    final runDir = scenarioRunDir(baseDir: base, scenario: 'f9_flujo');
    final names = Directory(runDir)
        .listSync()
        .map((f) => p.basename(f.path))
        .where((n) => n.endsWith('.png') && !n.endsWith('.diff.png'))
        .toList();

    expect(
      names,
      containsAll([
        'novicio-01_quieta.png', // idéntica: sin marca
        'novicio-02_poquito!!.png', // 1% → !!
        'novicio-03_bastante!!!!.png', // 30% → !!!!
      ]),
    );
    expect(
      File(p.join(runDir, 'novicio-03_bastante!!!!.diff.png')).existsSync(),
      isTrue,
      reason: 'con drift se escribe el tríptico',
    );
    expect(
      File(p.join(runDir, 'novicio-01_quieta.diff.png')).existsSync(),
      isFalse,
      reason: 'sin drift no hay nada que mostrar',
    );
  });

  test('los intents declarados llegan al manifest', () {
    shot('01-hodie.png');
    ingestPatrolRun(
      sourceDir: src,
      baseDir: base,
      scenario: 'f9-flujo',
      actor: 'novicio',
      intents: const {'hodie': 'el plan del día se ve completo'},
    );
    final steps = manifestOf('f9_flujo', 'novicio')['steps']! as List<Object?>;
    expect(
      (steps.first! as Map<String, Object?>)['intent'],
      'el plan del día se ve completo',
    );
  });

  test(
    'el steps.json del device manda: su intent pisa el que pase quien ingesta',
    () {
      shot('01-hodie.png');
      File(p.join(src, 'steps.json')).writeAsStringSync(
        jsonEncode({
          'flow': 'f9-flujo',
          'origin': 'patrol',
          'steps': [
            {
              'order': 1,
              'label': 'hodie',
              'intent': 'lo que el paso declaró en el device',
              'status': 'ok',
            },
          ],
        }),
      );

      ingestPatrolRun(
        sourceDir: src,
        baseDir: base,
        scenario: 'f9-flujo',
        actor: 'novicio',
        intents: const {'hodie': 'lo que inventó quien ingesta'},
      );

      final steps =
          manifestOf('f9_flujo', 'novicio')['steps']! as List<Object?>;
      expect(
        (steps.first! as Map<String, Object?>)['intent'],
        'lo que el paso declaró en el device',
        reason: 'el paso es el dueño de su contrato',
      );
    },
  );

  test('un steps.json ilegible no impide ingerir las capturas', () {
    shot('01-hodie.png');
    File(p.join(src, 'steps.json')).writeAsStringSync('{roto');

    final r = ingestPatrolRun(
      sourceDir: src,
      baseDir: base,
      scenario: 'f9-flujo',
      actor: 'novicio',
    );
    expect(r.captures, 1);
  });

  test('un directorio inexistente falla con un mensaje accionable', () {
    expect(
      () => ingestPatrolRun(
        sourceDir: p.join(tmp.path, 'no-existe'),
        baseDir: base,
        scenario: 'x',
        actor: 'y',
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('no existe'),
        ),
      ),
    );
  });
}
