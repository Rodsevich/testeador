import 'dart:async';

import 'package:test/test.dart';
import 'package:testeador/src/live/live_persona.dart';
import 'package:testeador/src/live/questline_live_client.dart';
import 'package:testeador/src/live/questline_scenario.dart';

/// Fake backend: the `ext.questline.*` extensions "appear" after
/// [registerAfter] polls; [result] is returned by every `call`.
class _FakeBackend implements PersonaVmBackend {
  _FakeBackend({
    this.registerAfter = 0,
    this.result = const <String, dynamic>{},
  });

  final int registerAfter;
  final Map<String, dynamic> result;

  int _polls = 0;
  bool disposed = false;
  final List<({String method, Map<String, dynamic> args})> calls =
      <({String method, Map<String, dynamic> args})>[];

  @override
  Future<String> mainIsolateId() async => 'iso-1';

  @override
  Future<Set<String>> extensionRPCs(String isolateId) async {
    final n = _polls++;
    if (n < registerAfter) return <String>{};
    return <String>{
      QuestlineLiveClient.dumpStateExt,
      QuestlineLiveClient.setSignalExt,
      QuestlineLiveClient.forceClockExt,
      QuestlineLiveClient.clearClockExt,
    };
  }

  @override
  Future<Map<String, dynamic>> call(
    String method,
    String isolateId,
    Map<String, dynamic> args,
  ) async {
    calls.add((method: method, args: args));
    return result;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

void main() {
  QuestlineLiveClient clientWith(_FakeBackend backend) => QuestlineLiveClient(
        wsUri: 'ws://localhost/ws',
        connect: (_) async => backend,
      );

  group('QuestlineLiveClient', () {
    test('dumpState invokes the extension with no args and returns body',
        () async {
      final backend = _FakeBackend(
        result: <String, dynamic>{
          'signals': <String, dynamic>{'feria': 3},
        },
      );
      final res = await clientWith(backend).dumpState();

      expect(backend.calls.single.method, QuestlineLiveClient.dumpStateExt);
      expect(backend.calls.single.args, isEmpty);
      expect(res['signals'], <String, dynamic>{'feria': 3});
      expect(backend.disposed, isTrue);
    });

    test('setSignal infers type and serializes value to string', () async {
      final backend = _FakeBackend();
      final client = clientWith(backend);

      await client.setSignal('feria', 1);
      await client.setSignal('unlockedOpusVita', true);
      await client.setSignal('label', 'hi');
      await client.setSignal('none', null);

      expect(backend.calls[0].method, QuestlineLiveClient.setSignalExt);
      expect(backend.calls[0].args,
          <String, dynamic>{'key': 'feria', 'value': '1', 'type': 'int'});
      expect(backend.calls[1].args, <String, dynamic>{
        'key': 'unlockedOpusVita',
        'value': 'true',
        'type': 'bool',
      });
      expect(backend.calls[2].args,
          <String, dynamic>{'key': 'label', 'value': 'hi', 'type': 'string'});
      expect(backend.calls[3].args,
          <String, dynamic>{'key': 'none', 'value': '', 'type': 'null'});
    });

    test('setSignal honors an explicit type', () async {
      final backend = _FakeBackend();
      await clientWith(backend).setSignal('x', '2', type: 'double');
      expect(backend.calls.single.args['type'], 'double');
    });

    test('forceHour sends minutes as a string', () async {
      final backend = _FakeBackend();
      await clientWith(backend).forceHour(660);
      expect(backend.calls.single.method, QuestlineLiveClient.forceClockExt);
      expect(backend.calls.single.args, <String, dynamic>{'minutes': '660'});
    });

    test('forceHour rejects out-of-range minutes', () {
      final client = clientWith(_FakeBackend());
      expect(() => client.forceHour(-1), throwsArgumentError);
      expect(() => client.forceHour(1440), throwsArgumentError);
    });

    test('forceClockIso sends the iso arg', () async {
      final backend = _FakeBackend();
      await clientWith(backend).forceClockIso('2026-07-17T12:00:00Z');
      expect(backend.calls.single.args,
          <String, dynamic>{'iso': '2026-07-17T12:00:00Z'});
    });

    test('forceLiturgicalHour maps names to minutes (accent-insensitive)',
        () async {
      final backend = _FakeBackend();
      final client = clientWith(backend);

      await client.forceLiturgicalHour('sexta');
      await client.forceLiturgicalHour('VÍSPERAS');

      expect(backend.calls[0].args, <String, dynamic>{'minutes': '660'});
      expect(backend.calls[1].args, <String, dynamic>{'minutes': '1020'});
    });

    test('forceLiturgicalHour rejects unknown names', () {
      expect(
        () => clientWith(_FakeBackend()).forceLiturgicalHour('nope'),
        throwsArgumentError,
      );
    });

    test('clearClock invokes its extension with no args', () async {
      final backend = _FakeBackend();
      await clientWith(backend).clearClock();
      expect(backend.calls.single.method, QuestlineLiveClient.clearClockExt);
      expect(backend.calls.single.args, isEmpty);
    });

    test('waits until the extension registers (discovery)', () async {
      final backend = _FakeBackend(registerAfter: 2);
      await clientWith(backend).dumpState();
      expect(backend.calls, hasLength(1));
    });

    test('actionable timeout if the extension never appears', () async {
      final backend = _FakeBackend(registerAfter: 1 << 30);
      await expectLater(
        clientWith(backend)
            .dumpState(timeout: const Duration(milliseconds: 150)),
        throwsA(isA<TimeoutException>()),
      );
      expect(backend.disposed, isTrue);
    });
  });

  group('QuestlineActor + QuestlineScenarioFixture', () {
    test('apply snapshots prior state, sets signals, then forces the clock',
        () async {
      final backend = _FakeBackend(
        result: <String, dynamic>{
          'signals': <String, dynamic>{
            'feria': <String, dynamic>{'value': '3', 'type': 'int'},
          },
        },
      );
      final actor = QuestlineActor(name: 't', client: clientWith(backend));

      const scenario = QuestlineScenario(
        signals: <String, Object?>{'feria': 1},
        liturgicalHour: 'sexta',
      );
      await actor.apply(scenario);

      expect(backend.calls.map((c) => c.method).toList(), <String>[
        QuestlineLiveClient.dumpStateExt,
        QuestlineLiveClient.setSignalExt,
        QuestlineLiveClient.forceClockExt,
      ]);
      expect(backend.calls[1].args['value'], '1');
      expect(backend.calls[2].args, <String, dynamic>{'minutes': '660'});
    });

    test('fixture load applies and dispose restores prior signals + clock',
        () async {
      final backend = _FakeBackend(
        result: <String, dynamic>{
          'signals': <String, dynamic>{
            'feria': <String, dynamic>{'value': '3', 'type': 'int'},
          },
        },
      );
      final actor = QuestlineActor(name: 't', client: clientWith(backend));
      final fixture = QuestlineScenarioFixture(
        actor: actor,
        scenario:
            const QuestlineScenario(signals: <String, Object?>{'feria': 1}),
      );

      final client = await fixture.load();
      await fixture.dispose(client);

      // load: dumpState + setSignal(feria=1)
      // dispose: setSignal(feria=3, restored) + clearClock
      expect(backend.calls.map((c) => c.method).toList(), <String>[
        QuestlineLiveClient.dumpStateExt,
        QuestlineLiveClient.setSignalExt,
        QuestlineLiveClient.setSignalExt,
        QuestlineLiveClient.clearClockExt,
      ]);
      expect(backend.calls[1].args['value'], '1');
      expect(backend.calls[2].args,
          <String, dynamic>{'key': 'feria', 'value': '3', 'type': 'int'});
    });
  });

  group('TestStep helpers', () {
    test('setSignalStep / forceHourStep / clearClockStep build steps', () async {
      final backend = _FakeBackend();
      final client = clientWith(backend);

      await setSignalStep(client, 'feria', 2).execute();
      await forceHourStep(client, 'nona').execute();
      await clearClockStep(client).execute();

      expect(backend.calls.map((c) => c.method).toList(), <String>[
        QuestlineLiveClient.setSignalExt,
        QuestlineLiveClient.forceClockExt,
        QuestlineLiveClient.clearClockExt,
      ]);
      expect(backend.calls[1].args, <String, dynamic>{'minutes': '840'});
    });

    test('assertSignalStep passes on match and throws on mismatch', () async {
      final backend = _FakeBackend(
        result: <String, dynamic>{
          'signals': <String, dynamic>{
            'unlockedOpusDiei': <String, dynamic>{'value': 'false'},
          },
        },
      );
      final client = clientWith(backend);

      await assertSignalStep(client, 'unlockedOpusDiei', false).execute();
      await expectLater(
        assertSignalStep(client, 'unlockedOpusDiei', true).execute(),
        throwsStateError,
      );
    });
  });
}
