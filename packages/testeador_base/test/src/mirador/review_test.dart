import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:testeador_base/evidence.dart';
import 'package:testeador_base/mirador.dart';

void main() {
  late Directory tmp;
  late String base;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mirador_review');
    base = p.join(tmp.path, 'test_evidence');
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  /// Escribe un manifest a mano: la cola se arma desde el manifest, así que
  /// este es el contrato de entrada que hay que ejercitar.
  void writeManifest(
    String scenario,
    String actor,
    List<Map<String, Object?>> steps,
  ) {
    final dir = scenarioRunDir(baseDir: base, scenario: scenario);
    Directory(dir).createSync(recursive: true);
    File(p.join(dir, '$actor.manifest.json')).writeAsStringSync(
      jsonEncode({
        'schemaVersion': 1,
        'scenario': scenario,
        'actor': actor,
        'steps': steps,
      }),
    );
  }

  Map<String, Object?> step(
    String slug, {
    int marks = 0,
    double ratio = 0,
    String status = 'ok',
    bool withBaseline = true,
    String? intent,
    String? exception,
  }) => {
    'order': 1,
    'slug': slug,
    'description': slug,
    'status': status,
    'intent': ?intent,
    'capture': '$slug.png',
    if (withBaseline) 'baseline': '../../baseline/x/$slug.png',
    if (withBaseline)
      'diff': {'ratio': ratio, 'marks': marks, 'dimensionMismatch': false},
    'exception': ?exception,
  };

  test('la cola se ordena por marcas descendente: lo grave primero', () {
    writeManifest('flujo', 'actor', [
      step('leve', marks: 1, ratio: 0.001),
      step('grave', marks: 4, ratio: 0.2),
      step('medio', marks: 2, ratio: 0.01),
    ]);

    final q = loadQueue(baseDir: base);
    expect(q.map((i) => i.slug), equals(['grave', 'medio', 'leve']));
  });

  test('las capturas sin cambios se filtran, salvo que se pidan', () {
    writeManifest('flujo', 'actor', [
      step('quieta'),
      step('movida', marks: 2, ratio: 0.01),
    ]);

    expect(loadQueue(baseDir: base).map((i) => i.slug), equals(['movida']));
    expect(
      loadQueue(baseDir: base, includeUnchanged: true).map((i) => i.slug),
      containsAll(['movida', 'quieta']),
    );
  });

  test('un paso que falló se propone como fix_code con su excepción', () {
    writeManifest('flujo', 'actor', [
      step(
        'explotó',
        status: 'failed',
        withBaseline: false,
        exception: 'StateError: la app explotó',
      ),
    ]);

    final item = loadQueue(baseDir: base).single;
    expect(item.proposedVerdict, Verdict.fixCode);
    expect(item.rationale, contains('la app explotó'));
  });

  test('una captura ~new NO se auto-aprueba: queda inconclusive', () {
    writeManifest('flujo', 'actor', [step('nueva', withBaseline: false)]);

    final item = loadQueue(baseDir: base).single;
    expect(item.isNew, isTrue);
    expect(
      item.proposedVerdict,
      Verdict.inconclusive,
      reason: 'adoptar una pantalla rota envenena toda comparación futura',
    );
  });

  test('el drift sin causa declarada tampoco se auto-aprueba', () {
    writeManifest('flujo', 'actor', [step('movida', marks: 3, ratio: 0.05)]);
    expect(
      loadQueue(baseDir: base).single.proposedVerdict,
      Verdict.inconclusive,
    );
  });

  test('la propuesta del agente pisa la heurística', () {
    writeManifest('flujo', 'actor', [step('movida', marks: 3, ratio: 0.05)]);

    final q = loadQueue(
      baseDir: base,
      proposals: {
        'flujo/actor/movida': const Proposal(
          Verdict.replaceBaseline,
          'es el padding que pedí',
        ),
      },
    );
    expect(q.single.proposedVerdict, Verdict.replaceBaseline);
    expect(q.single.rationale, 'es el padding que pedí');
  });

  test('un manifest ilegible no tumba la revisión del resto', () {
    writeManifest('bueno', 'actor', [step('ok', marks: 1, ratio: 0.001)]);
    final dir = scenarioRunDir(baseDir: base, scenario: 'roto');
    Directory(dir).createSync(recursive: true);
    File(p.join(dir, 'actor.manifest.json')).writeAsStringSync('{no es json');

    expect(loadQueue(baseDir: base).map((i) => i.slug), equals(['ok']));
  });

  test(
    'con baseDir RELATIVO las rutas salen absolutas: el server sólo puede '
    'resolverlas contra su sandbox, no contra el cwd',
    () {
      final previo = Directory.current;
      Directory.current = tmp;
      addTearDown(() => Directory.current = previo);

      writeManifest('flujo', 'actor', [step('movida', marks: 2, ratio: 0.01)]);
      // Relativo, como lo pasa el CLI por defecto (`--base-dir test_evidence`).
      final item = loadQueue(baseDir: 'test_evidence').single;

      expect(p.isAbsolute(item.capture!), isTrue, reason: item.capture);
      expect(p.isAbsolute(item.baseline!), isTrue, reason: item.baseline);
    },
  );

  test(
    'las variantes se detectan por convención de directorio, ordenadas',
    () {
      writeManifest('flujo', 'actor', [step('movida', marks: 2, ratio: 0.01)]);
      final vd = Directory(
        p.join(
          scenarioRunDir(baseDir: base, scenario: 'flujo'),
          'variants',
          'actor-movida',
        ),
      )..createSync(recursive: true);
      // Desordenadas a propósito: la tira las numera por nombre.
      for (final n in ['03-banda', '01-titular', '02-card']) {
        File(p.join(vd.path, '$n.png')).writeAsBytesSync(const [1, 2, 3]);
      }

      final item = loadQueue(baseDir: base).single;
      expect(item.variants, hasLength(3));
      expect(
        item.variants.map(p.basename),
        equals(['01-titular.png', '02-card.png', '03-banda.png']),
      );
      expect(item.variants.every(p.isAbsolute), isTrue);
    },
  );

  test('sin variantes en disco, la lista queda vacía', () {
    writeManifest('flujo', 'actor', [step('movida', marks: 2, ratio: 0.01)]);
    expect(loadQueue(baseDir: base).single.variants, isEmpty);
  });

  test('la variante elegida viaja en el veredicto', () {
    appendVerdicts(
      baseDir: base,
      decisions: const [
        Decision(
          scenario: 'flujo',
          actor: 'actor',
          slug: 'movida',
          verdict: Verdict.variants,
          rationale: 'Elegida la variante II de 3.',
          judgedBy: 'human',
          chosenVariant: '02-card.png',
        ),
      ],
      judgedAt: 't',
    );
    final v =
        (jsonDecode(
                  File(
                    p.join(
                      scenarioBaselineDir(baseDir: base, scenario: 'flujo'),
                      'verdicts.json',
                    ),
                  ).readAsStringSync(),
                )
                as Map<String, Object?>)['verdicts']!
            as List;
    expect(
      (v.single as Map<String, Object?>)['chosenVariant'],
      '02-card.png',
    );
  });

  test('sin runs/ la cola es vacía y no explota', () {
    expect(loadQueue(baseDir: base), isEmpty);
  });

  group('appendVerdicts', () {
    Decision decision(String slug, Verdict v, {List<Mark> marks = const []}) =>
        Decision(
          scenario: 'flujo',
          actor: 'actor',
          slug: slug,
          verdict: v,
          rationale: 'porque sí',
          judgedBy: marks.isEmpty ? 'agent' : 'human',
          capture: '$slug.png',
          marks: marks,
        );

    Map<String, Object?> read() =>
        jsonDecode(
              File(
                p.join(
                  scenarioBaselineDir(baseDir: base, scenario: 'flujo'),
                  'verdicts.json',
                ),
              ).readAsStringSync(),
            )
            as Map<String, Object?>;

    test('crea el archivo con el esqueleto del schema', () {
      appendVerdicts(
        baseDir: base,
        decisions: [decision('a', Verdict.replaceBaseline)],
        judgedAt: '2026-07-28T00:00:00.000Z',
      );

      final doc = read();
      expect(doc['schemaVersion'], 1);
      final v = (doc['verdicts']! as List).single as Map<String, Object?>;
      expect(v['slug'], 'a');
      expect(v['verdict'], 'replace_baseline');
      expect(v['judgedAt'], '2026-07-28T00:00:00.000Z');
      expect(v['judgedBy'], 'agent');
    });

    test('appendea sin perder los veredictos anteriores', () {
      appendVerdicts(
        baseDir: base,
        decisions: [decision('a', Verdict.replaceBaseline)],
        judgedAt: 't1',
      );
      appendVerdicts(
        baseDir: base,
        decisions: [decision('b', Verdict.fixCode)],
        judgedAt: 't2',
      );

      final list = read()['verdicts']! as List;
      expect(list, hasLength(2));
      expect(
        list.map((e) => (e as Map<String, Object?>)['slug']),
        equals(['a', 'b']),
      );
    });

    test('las marcas pintadas viajan con su pincel, rect y nota', () {
      appendVerdicts(
        baseDir: base,
        decisions: [
          decision(
            'c',
            Verdict.fixCode,
            marks: const [
              Mark(
                brushId: 'modificar',
                rect: [10, 20, 30, 40],
                note: 'esto está torcido',
                points: [
                  [10, 20],
                  [40, 60],
                ],
              ),
            ],
          ),
        ],
        judgedAt: 't',
      );

      final v = (read()['verdicts']! as List).single as Map<String, Object?>;
      expect(v['judgedBy'], 'human');
      final m = (v['marks']! as List).single as Map<String, Object?>;
      expect(m['brush'], 'modificar');
      expect(m['note'], 'esto está torcido');
      expect(m['rect'], equals([10, 20, 30, 40]));
    });

    test(
      'un verdicts.json corrupto se preserva en .bak antes de reescribir',
      () {
        final dir = scenarioBaselineDir(baseDir: base, scenario: 'flujo');
        Directory(dir).createSync(recursive: true);
        final file = File(p.join(dir, 'verdicts.json'))
          ..writeAsStringSync('{roto');

        appendVerdicts(
          baseDir: base,
          decisions: [decision('a', Verdict.fixCode)],
          judgedAt: 't',
        );

        expect(File('${file.path}.bak').readAsStringSync(), '{roto');
        expect(read()['verdicts']! as List, hasLength(1));
      },
    );
  });
}
