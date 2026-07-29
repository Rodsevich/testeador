import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:testeador/testeador.dart';

/// Minimal two-screen app: a home with a button that navigates to a detail
/// screen — enough to exercise real patrol_finders interaction.
class _MiniApp extends StatelessWidget {
  const _MiniApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Home')),
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const Scaffold(body: Center(child: Text('Detalle'))),
                ),
              ),
              child: const Text('Ver detalle'),
            ),
          ),
        ),
      ),
    );
  }
}

/// The world: whatever the fixture seeded. Empty here — the app is
/// self-contained.
final class _World {
  const _World();
}

/// An actor: a persona with its own session over the world.
final class _MiniActor extends UiActor<_World> {
  _MiniActor(String name) : super(name: name);

  @override
  Future<Widget Function()> session(_World world) async =>
      () => const _MiniApp();
}

/// Actor que llama a una API durante su sesión: el interceptor registra el
/// curl aunque la request falle (flutter_test bloquea la red).
final class _ActorConTrafico extends UiActor<_World> {
  _ActorConTrafico(String name) : super(name: name);

  @override
  Future<Widget Function()> session(_World world) async {
    try {
      await dio.get<void>('http://127.0.0.1:1/pedido');
    } on Object {
      // La request no puede completarse en un widget test; lo que importa es
      // que el interceptor ya la anotó.
    }
    return () => const _MiniApp();
  }
}

final class _UiFixture extends Fixture<_World> {
  @override
  Future<_World> load() async => const _World();
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('testeador_uiflow');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  EvidenceConfig config() => (
    baseDir: tmp.path,
    capturePixelRatio: 1.0,
    noiseFloor: 0.0001,
    maxMarks: 5,
    channelTolerance: 8,
  );

  group('actor-driven contract', () {
    test(
      'an Actor exposes its name and opens a session over the world',
      () async {
        // Deliberately non-const: exercises the runtime constructor path.
        // ignore: prefer_const_constructors
        final actor = _MiniActor('admin');
        expect(actor.name, 'admin');
        final app = await actor.session(const _World());
        expect(app(), isA<Widget>());
      },
    );

    test('run() without an actor throws with guidance', () {
      final flow = UiTestFlow<_World>(name: 'x', steps: const []);
      expect(
        () => flow.run(() => const _World()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('actors'),
          ),
        ),
      );
    });

    test('an entry with actor-driven flows and no actors fails loudly', () {
      final entry = TestSuite.entry<_World>(
        fixture: _UiFixture(),
        flows: [UiTestFlow<_World>(name: 'sin_actores', steps: const [])],
      );
      expect(entry.register, throwsArgumentError);
    });
  });

  group('UiTestFlow construction', () {
    test('rejects colliding step slugs at construction time', () {
      expect(
        () => UiTestFlow<_World>(
          name: 'checkout',
          steps: [
            (description: 'Home!', intent: 'x', body: (_, _) async {}),
            (description: 'home', intent: 'y', body: (_, _) async {}),
          ],
        ),
        throwsArgumentError,
      );
    });
  });

  group('UiTestFlow.execute', () {
    testWidgets('photographs every step automatically, in order', (
      tester,
    ) async {
      final flow = UiTestFlow<_World>(
        name: 'navegacion',
        config: config(),
        steps: [
          (
            description: 'home',
            intent: 'shows the home with the detail button',
            body: (ctx, $) async {},
          ),
          (
            description: 'detalle',
            intent: 'shows the detail screen',
            body: (ctx, $) async {
              await $('Ver detalle').tap();
            },
          ),
        ],
      );

      await flow.execute(
        tester,
        const _World(),
        actor: _MiniActor('comprador'),
      );

      final runDir = scenarioRunDir(baseDir: tmp.path, scenario: 'navegacion');
      expect(
        File(p.join(runDir, 'comprador-01_home~new.png')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(runDir, 'comprador-02_detalle~new.png')).existsSync(),
        isTrue,
      );

      final manifest =
          jsonDecode(
                File(
                  p.join(runDir, 'comprador.manifest.json'),
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      final steps = manifest['steps']! as List<Object?>;
      expect(steps, hasLength(2));
      expect(
        steps.first,
        allOf(
          containsPair('slug', 'home'),
          containsPair('intent', 'shows the home with the detail button'),
          containsPair('status', 'ok'),
        ),
      );
    });

    testWidgets(
      'crash in step 3 of 5: photos of 1-2, ~crash capture of 3, steps 4-5 '
      'skipped, manifest complete, original exception rethrown',
      (tester) async {
        Future<void> noop(_World world, dynamic $) async {}
        final flow = UiTestFlow<_World>(
          name: 'con_crash',
          config: config(),
          steps: [
            (description: 'paso_1', intent: 'i1', body: noop),
            (description: 'paso_2', intent: 'i2', body: noop),
            (
              description: 'paso_3',
              intent: 'i3',
              body: (_, _) async => throw StateError('la app explotó'),
            ),
            (description: 'paso_4', intent: 'i4', body: noop),
            (description: 'paso_5', intent: 'i5', body: noop),
          ],
        );

        await expectLater(
          () => flow.execute(
            tester,
            const _World(),
            actor: _MiniActor('comprador'),
          ),
          throwsStateError,
        );

        final runDir = scenarioRunDir(baseDir: tmp.path, scenario: 'con_crash');
        expect(
          File(p.join(runDir, 'comprador-01_paso_1~new.png')).existsSync(),
          isTrue,
        );
        expect(
          File(p.join(runDir, 'comprador-02_paso_2~new.png')).existsSync(),
          isTrue,
        );
        expect(
          File(p.join(runDir, 'comprador-03_paso_3~crash.png')).existsSync(),
          isTrue,
          reason: 'the crash state is the most valuable evidence of the run',
        );

        final manifest =
            jsonDecode(
                  File(
                    p.join(runDir, 'comprador.manifest.json'),
                  ).readAsStringSync(),
                )
                as Map<String, Object?>;
        final steps = (manifest['steps']! as List<Object?>)
            .cast<Map<String, Object?>>();
        expect(steps, hasLength(5), reason: 'manifest lists ALL steps');
        expect(steps[0]['status'], 'ok');
        expect(steps[1]['status'], 'ok');
        expect(steps[2]['status'], 'failed');
        expect(steps[2]['exception'], contains('la app explotó'));
        expect(steps[3]['status'], 'skipped');
        expect(steps[4]['status'], 'skipped');
      },
    );

    testWidgets('reconciles orphaned baselines even on a green run', (
      tester,
    ) async {
      final baselineDir = scenarioBaselineDir(
        baseDir: tmp.path,
        scenario: 'huerfanos',
      );
      File(p.join(baselineDir, 'comprador-renombrado.png'))
        ..parent.createSync(recursive: true)
        ..createSync();

      final flow = UiTestFlow<_World>(
        name: 'huerfanos',
        config: config(),
        steps: [(description: 'home', intent: 'i', body: (_, _) async {})],
      );
      await flow.execute(
        tester,
        const _World(),
        actor: _MiniActor('comprador'),
      );

      final runDir = scenarioRunDir(baseDir: tmp.path, scenario: 'huerfanos');
      final manifest =
          jsonDecode(
                File(
                  p.join(runDir, 'comprador.manifest.json'),
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(
        manifest['orphanedBaselines'],
        equals(['comprador-renombrado.png']),
      );
    });
  });

  group('curls del paso que falló', () {
    testWidgets(
      'un paso que explota deja sus curls adjuntos en el manifest, y el juez '
      'los ve junto a la captura del crash',
      (tester) async {
        final actor = _ActorConTrafico('comprador');
        final flow = UiTestFlow<_World>(
          name: 'con_trafico',
          config: config(),
          steps: [
            (
              description: 'explota',
              intent: 'la pantalla no debería explotar',
              body: (_, _) async => throw StateError('la API dijo que no'),
            ),
          ],
        );

        await expectLater(
          () => flow.execute(tester, const _World(), actor: actor),
          throwsStateError,
        );

        final runDir = scenarioRunDir(
          baseDir: tmp.path,
          scenario: 'con_trafico',
        );
        final curls = File(p.join(runDir, 'http', 'comprador-explota.curl'));
        expect(
          curls.existsSync(),
          isTrue,
          reason: 'el dump es el input #4 del contrato de veredicto',
        );
        expect(curls.readAsStringSync(), contains('127.0.0.1:1/pedido'));

        final steps =
            (jsonDecode(
                      File(
                        p.join(runDir, 'comprador.manifest.json'),
                      ).readAsStringSync(),
                    )
                    as Map<String, Object?>)['steps']!
                as List<Object?>;
        final att =
            (steps.single! as Map<String, Object?>)['attachments']!
                as Map<String, Object?>;
        expect(
          (att['http']! as List).single,
          contains('comprador-explota.curl'),
        );
      },
    );

    testWidgets('un actor que no llama APIs no escribe ningún curl', (
      tester,
    ) async {
      final flow = UiTestFlow<_World>(
        name: 'sin_trafico',
        config: config(),
        steps: [
          (
            description: 'explota',
            intent: 'x',
            body: (_, _) async => throw StateError('sin red de por medio'),
          ),
        ],
      );

      await expectLater(
        () => flow.execute(tester, const _World(), actor: _MiniActor('mudo')),
        throwsStateError,
      );

      final runDir = scenarioRunDir(baseDir: tmp.path, scenario: 'sin_trafico');
      expect(Directory(p.join(runDir, 'http')).existsSync(), isFalse);
    });
  });

  group('geometric combination: 1 fixture × 2 actors × 2 flows', () {
    final geomTmp = Directory.systemTemp.createTempSync('testeador_geom');
    UiTestFlow<_World> flowNamed(String name) => UiTestFlow<_World>(
      name: name,
      config: (
        baseDir: geomTmp.path,
        capturePixelRatio: 1.0,
        noiseFloor: 0.0001,
        maxMarks: 5,
        channelTolerance: 8,
      ),
      steps: [
        (description: 'home', intent: 'shows home', body: (_, _) async {}),
      ],
    );

    TestSuite(
      name: 'Geometría',
      entries: [
        TestSuite.entry<_World>(
          fixture: _UiFixture(),
          actors: [_MiniActor('comprador'), _MiniActor('visitante')],
          flows: [flowNamed('flujo_a'), flowNamed('flujo_b')],
        ),
      ],
    ).register();

    test('the 4 runs produced 4 independent evidence sets', () {
      for (final scenario in ['flujo_a', 'flujo_b']) {
        final runDir = scenarioRunDir(
          baseDir: geomTmp.path,
          scenario: scenario,
        );
        for (final actor in ['comprador', 'visitante']) {
          expect(
            File(p.join(runDir, '$actor-01_home~new.png')).existsSync(),
            isTrue,
            reason: 'missing $scenario/$actor',
          );
          expect(
            File(p.join(runDir, '$actor.manifest.json')).existsSync(),
            isTrue,
          );
        }
      }
      geomTmp.deleteSync(recursive: true);
    });
  });

  group('TestSuite integration', () {
    // Registered at declaration time, like every testeador suite. The flow
    // runs as a real testWidgets inside the group structure.
    final integrationTmp = Directory.systemTemp.createTempSync(
      'testeador_uiflow_suite',
    );
    final executionLog = <String>[];

    TestSuite(
      name: 'Suite con UiTestFlow',
      entries: [
        TestSuite.entry<_World>(
          fixture: _UiFixture(),
          actors: [_MiniActor('comprador')],
          flows: [
            // Solo flujos de UI. Los flujos de contrato de `testeador_base`
            // (TestFlowLasting/TestFlowTransient) son data classes que ejecuta
            // `Testeador`, no RegistrableFlow: no se mezclan en una entry.
            UiTestFlow<_World>(
              name: 'ui evidencia',
              config: (
                baseDir: integrationTmp.path,
                capturePixelRatio: 1.0,
                noiseFloor: 0.0001,
                maxMarks: 5,
                channelTolerance: 8,
              ),
              steps: [
                (
                  description: 'home',
                  intent: 'shows home',
                  body: (ctx, $) async => executionLog.add('ui'),
                ),
              ],
            ),
          ],
        ),
      ],
    ).register();

    test('UI flow ran through the suite and produced its artifacts', () {
      expect(executionLog, equals(['ui']));
      final runDir = scenarioRunDir(
        baseDir: integrationTmp.path,
        scenario: 'ui evidencia',
      );
      expect(
        File(p.join(runDir, 'comprador-01_home~new.png')).existsSync(),
        isTrue,
      );
      integrationTmp.deleteSync(recursive: true);
    });
  });
}
