import 'dart:async';

import 'package:dev_mate_client/dev_mate_client.dart';
import 'package:test/test.dart';
import 'package:testeador/src/live/questline_live_client.dart';
import 'package:testeador/src/live/questline_scenario.dart';

/// Catálogo con los presets litúrgicos que publicaría la app (D8): la verdad
/// del mapa label→minutos vive app-side; el cliente la lee de acá.
const _catalog = <String, dynamic>{
  'version': 1,
  'domains': <Object?>[
    <String, dynamic>{
      'name': 'clock',
      'prefix': 'dev_mate.clock',
      'actions': <Object?>[
        <String, dynamic>{
          'name': 'force',
          'extension': 'ext.dev_mate.clock.force',
          'params': <Object?>[
            <String, dynamic>{
              'name': 'minutes',
              'enumValues': <Object?>[
                <String, dynamic>{'label': 'sexta', 'value': '660'},
                <String, dynamic>{'label': 'vísperas', 'value': '1020'},
              ],
            },
          ],
        },
      ],
    },
  ],
};

void main() {
  FakeVmBackend backend({
    Map<String, dynamic> result = const <String, dynamic>{},
  }) => FakeVmBackend(
    extensions: const <String>{
      DevMateClient.catalogExtension,
      QuestlineLiveClient.dumpStateExt,
      QuestlineLiveClient.setSignalExt,
      QuestlineLiveClient.forceClockExt,
      QuestlineLiveClient.clearClockExt,
    },
    onCall: (method, _) =>
        method == DevMateClient.catalogExtension ? _catalog : result,
  );

  QuestlineLiveClient clientWith(FakeVmBackend b) =>
      QuestlineLiveClient(wsUri: 'ws://localhost/ws', connect: (_) async => b);

  test('setSignal serializa el valor e infiere el type', () async {
    final b = backend();
    await clientWith(b).setSignal('unlockedVita', true);
    expect(b.calls.first.method, QuestlineLiveClient.setSignalExt);
    expect(b.calls.first.args, <String, dynamic>{
      'key': 'unlockedVita',
      'value': 'true',
      'type': 'bool',
    });
  });

  test(
    'forceHour valida el rango y pega al dominio clock de dev_mate',
    () async {
      final b = backend();
      await clientWith(b).forceHour(660);
      expect(b.calls.first.method, 'ext.dev_mate.clock.force');
      expect(b.calls.first.args, <String, dynamic>{'minutes': '660'});

      expect(() => clientWith(backend()).forceHour(1500), throwsArgumentError);
    },
  );

  test(
    'forceLiturgicalHour resuelve el label desde los presets del catálogo '
    '(sin mapa local)',
    () async {
      final b = backend();
      await clientWith(b).forceLiturgicalHour('  Sexta ');
      final force = b.calls.singleWhere(
        (c) => c.method == 'ext.dev_mate.clock.force',
      );
      expect(force.args, <String, dynamic>{'minutes': '660'});
    },
  );

  test('forceLiturgicalHour matchea labels con acento (visperas)', () async {
    final b = backend();
    await clientWith(b).forceLiturgicalHour('visperas');
    final force = b.calls.singleWhere(
      (c) => c.method == 'ext.dev_mate.clock.force',
    );
    expect(force.args, <String, dynamic>{'minutes': '1020'});
  });

  test('forceLiturgicalHour con label desconocido es accionable', () async {
    await expectLater(
      clientWith(backend()).forceLiturgicalHour('maitines'),
      throwsA(
        isA<ArgumentError>().having(
          (e) => '${e.message}',
          'message',
          contains('sexta'),
        ),
      ),
    );
  });

  test('clearClock pega al dominio clock y dumpState al questline', () async {
    final b = backend();
    final client = clientWith(b);
    // invoke() agrega una consulta final al catálogo (marca inCatalog):
    // comparar contra la última llamada NO-catálogo.
    String lastAction() => b.calls
        .lastWhere((c) => c.method != DevMateClient.catalogExtension)
        .method;
    await client.clearClock();
    expect(lastAction(), 'ext.dev_mate.clock.clear');
    await client.dumpState();
    expect(lastAction(), 'ext.questline.dumpState');
  });

  test('timeout accionable si la app no expone las extensions', () async {
    final b = FakeVmBackend(registerAfter: 1 << 30);
    await expectLater(
      QuestlineLiveClient(
        wsUri: 'ws://localhost/ws',
        connect: (_) async => b,
      ).dumpState(timeout: const Duration(milliseconds: 150)),
      throwsA(isA<TimeoutException>()),
    );
    expect(b.disposed, isTrue);
  });

  test('QuestlineScenario.toScenario mapea signals y reloj a pasos wire', () {
    // El puente deprecado es exactamente lo que se testea acá.
    // ignore: deprecated_member_use_from_same_package
    const scenario = QuestlineScenario(
      name: 'x',
      signals: <String, Object?>{'unlockedVita': true},
      clockMinutes: 660,
    );
    final generic = scenario.toScenario();
    expect(generic.steps, hasLength(2));
    expect(generic.steps.first.extension, 'ext.questline.setSignal');
    expect(generic.steps.first.args, <String, String>{
      'key': 'unlockedVita',
      'value': 'true',
      'type': 'bool',
    });
    expect(generic.steps.last.extension, 'ext.dev_mate.clock.force');
    expect(generic.restoreSteps.single.extension, 'ext.dev_mate.clock.clear');
  });

  test('toScenario con clockIso usa el param iso', () {
    // El puente deprecado es exactamente lo que se testea acá.
    // ignore: deprecated_member_use_from_same_package
    const scenario = QuestlineScenario(name: 'x', clockIso: '2026-07-01T06:00');
    final generic = scenario.toScenario();
    expect(generic.steps.single.args, <String, String>{
      'iso': '2026-07-01T06:00',
    });
  });

  test(
    'toScenario con SOLO liturgicalHour documenta la asimetría: sin step de '
    'reloj (el label se resuelve app-side) pero con restore del clear',
    () {
      // El puente deprecado es exactamente lo que se testea acá.
      // ignore: deprecated_member_use_from_same_package
      const scenario = QuestlineScenario(name: 'x', liturgicalHour: 'sexta');
      final generic = scenario.toScenario();
      expect(generic.steps, isEmpty);
      expect(
        generic.restoreSteps.single.extension,
        'ext.dev_mate.clock.clear',
      );
    },
  );
}
