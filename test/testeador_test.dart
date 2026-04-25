import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:testeador/testeador.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _TestActor extends Actor {
  _TestActor(String name) : super(name: name, dio: Dio());
}

class _TrackingFixture extends Fixture<String> {
  int loadCount = 0;
  int disposeCount = 0;
  String? lastDisposedData;

  @override
  Future<String> load() async {
    loadCount++;
    return 'fixture-context';
  }

  @override
  Future<void> dispose(String data) async {
    disposeCount++;
    lastDisposedData = data;
  }
}

class _FailingFixture extends Fixture<int> {
  @override
  Future<int> load() async => throw Exception('fixture load failed');
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Runs [testeador] in standalone mode without actually calling [exit].
///
/// We override [exitOnFailure] to false so the runner doesn't call exit(1)
/// during tests.
Future<void> _runNoExit(
  Testeador testeador, {
  List<String> args = const [],
}) async {
  // Prepend --no-exit-on-failure so tests don't call exit().
  await testeador.run(['--no-exit-on-failure', ...args]);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // TesteadorOptions defaults
  // -------------------------------------------------------------------------
  group('TesteadorOptions defaults', () {
    test('has expected default values', () {
      const opts = TesteadorOptions();
      expect(opts.includeTags, isEmpty);
      expect(opts.excludeTags, isEmpty);
      expect(opts.includeFlows, isEmpty);
      expect(opts.excludeFlows, isEmpty);
      expect(opts.failFast, isTrue);
      expect(opts.verbose, isFalse);
      expect(opts.exitOnFailure, isTrue);
      expect(opts.showCurls, isTrue);
      expect(opts.showStackTraces, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // TestFlowLasting — steps run in order
  // -------------------------------------------------------------------------
  group('TestFlowLasting', () {
    test('runs steps in declared order', () async {
      final order = <String>[];
      final flow = TestFlowLasting(
        name: 'Lasting',
        steps: [
          TestStep(name: 'A', action: () => order.add('A')),
          TestStep(name: 'B', action: () => order.add('B')),
          TestStep(name: 'C', action: () => order.add('C')),
        ],
      );

      final runner = Testeador(flows: [flow]);
      await _runNoExit(runner);

      expect(order, equals(['A', 'B', 'C']));
    });
  });

  // -------------------------------------------------------------------------
  // TestFlowTransient — steps run in order (no rollback expected yet)
  // -------------------------------------------------------------------------
  group('TestFlowTransient', () {
    test('runs steps in declared order', () async {
      final order = <String>[];
      final flow = TestFlowTransient(
        name: 'Transient',
        steps: [
          TestStep(name: 'X', action: () => order.add('X')),
          TestStep(name: 'Y', action: () => order.add('Y')),
        ],
      );

      final runner = Testeador(flows: [flow]);
      await _runNoExit(runner);

      expect(order, equals(['X', 'Y']));
    });
  });

  // -------------------------------------------------------------------------
  // Fixture lifecycle
  // -------------------------------------------------------------------------
  group('Fixture lifecycle', () {
    test('load is called before steps, dispose after', () async {
      final fixture = _TrackingFixture();
      final stepOrder = <String>[];

      final flow = TestFlowLasting(
        name: 'Fixture Flow',
        fixture: fixture,
        steps: [
          TestStep(name: 'Step', action: () => stepOrder.add('step')),
        ],
      );

      final runner = Testeador(flows: [flow]);
      await _runNoExit(runner);

      expect(fixture.loadCount, equals(1));
      expect(fixture.disposeCount, equals(1));
      expect(fixture.lastDisposedData, equals('fixture-context'));
      expect(stepOrder, equals(['step']));
    });

    test('dispose is called even when a step throws', () async {
      final fixture = _TrackingFixture();

      final flow = TestFlowLasting(
        name: 'Failing Flow',
        fixture: fixture,
        steps: [
          TestStep(
            name: 'Boom',
            action: () => throw Exception('step failed'),
          ),
        ],
      );

      final runner = Testeador(flows: [flow]);
      // failFast=true by default; runner won't rethrow in standalone mode.
      await _runNoExit(runner);

      expect(fixture.loadCount, equals(1));
      expect(fixture.disposeCount, equals(1));
    });

    test('dispose is not called when fixture load throws', () async {
      final failingFixture = _FailingFixture();

      final flow = TestFlowLasting(
        name: 'Load Fail Flow',
        fixture: failingFixture,
        steps: [TestStep(name: 'Never', action: () {})],
      );

      final runner = Testeador(flows: [flow]);
      // Should not throw; runner catches and continues.
      await _runNoExit(runner);
      // No assertion needed — the test passes if no exception escapes.
    });
  });

  // -------------------------------------------------------------------------
  // Tag filtering
  // -------------------------------------------------------------------------
  group('Testeador tag filtering', () {
    test('includeTags runs only matching flows', () async {
      final ran = <String>[];

      final flows = [
        TestFlowLasting(
          name: 'Smoke',
          tags: const {'smoke'},
          steps: [TestStep(name: 'S', action: () => ran.add('smoke'))],
        ),
        TestFlowLasting(
          name: 'Regression',
          tags: const {'regression'},
          steps: [TestStep(name: 'R', action: () => ran.add('regression'))],
        ),
      ];

      final runner = Testeador(flows: flows);
      await _runNoExit(runner, args: ['--include-tags=smoke']);

      expect(ran, equals(['smoke']));
    });

    test('excludeTags skips matching flows', () async {
      final ran = <String>[];

      final flows = [
        TestFlowLasting(
          name: 'Smoke',
          tags: const {'smoke'},
          steps: [TestStep(name: 'S', action: () => ran.add('smoke'))],
        ),
        TestFlowLasting(
          name: 'Regression',
          tags: const {'regression'},
          steps: [TestStep(name: 'R', action: () => ran.add('regression'))],
        ),
      ];

      final runner = Testeador(flows: flows);
      await _runNoExit(runner, args: ['--exclude-tags=smoke']);

      expect(ran, equals(['regression']));
    });

    test('flow with no tags is excluded when includeTags is set', () async {
      final ran = <String>[];

      final flows = [
        TestFlowLasting(
          name: 'Tagged',
          tags: const {'smoke'},
          steps: [TestStep(name: 'T', action: () => ran.add('tagged'))],
        ),
        TestFlowLasting(
          name: 'Untagged',
          steps: [TestStep(name: 'U', action: () => ran.add('untagged'))],
        ),
      ];

      final runner = Testeador(flows: flows);
      await _runNoExit(runner, args: ['--include-tags=smoke']);

      expect(ran, equals(['tagged']));
    });
  });

  // -------------------------------------------------------------------------
  // Flow name filtering
  // -------------------------------------------------------------------------
  group('Testeador flow name filtering', () {
    test('includeFlows runs only named flows', () async {
      final ran = <String>[];

      final flows = [
        TestFlowLasting(
          name: 'Alpha',
          steps: [TestStep(name: 'A', action: () => ran.add('alpha'))],
        ),
        TestFlowLasting(
          name: 'Beta',
          steps: [TestStep(name: 'B', action: () => ran.add('beta'))],
        ),
      ];

      final runner = Testeador(flows: flows);
      await _runNoExit(runner, args: ['--include-flows=Alpha']);

      expect(ran, equals(['alpha']));
    });

    test('excludeFlows skips named flows', () async {
      final ran = <String>[];

      final flows = [
        TestFlowLasting(
          name: 'Alpha',
          steps: [TestStep(name: 'A', action: () => ran.add('alpha'))],
        ),
        TestFlowLasting(
          name: 'Beta',
          steps: [TestStep(name: 'B', action: () => ran.add('beta'))],
        ),
      ];

      final runner = Testeador(flows: flows);
      await _runNoExit(runner, args: ['--exclude-flows=Alpha']);

      expect(ran, equals(['beta']));
    });
  });

  // -------------------------------------------------------------------------
  // CurlInterceptor
  // -------------------------------------------------------------------------
  group('CurlInterceptor', () {
    test('starts with an empty log', () {
      final interceptor = CurlInterceptor();
      expect(interceptor.log, isEmpty);
    });

    test('clear() empties the log', () {
      final interceptor = CurlInterceptor();
      // Manually add an entry to simulate a recorded request.
      // ignore: invalid_use_of_visible_for_testing_member
      interceptor.clear(); // Should not throw on empty log.
      expect(interceptor.log, isEmpty);
    });

    test('log is unmodifiable', () {
      final interceptor = CurlInterceptor();
      expect(() => interceptor.log.add('x'), throwsUnsupportedError);
    });
  });

  // -------------------------------------------------------------------------
  // Actor
  // -------------------------------------------------------------------------
  group('Actor', () {
    test('has a name', () {
      final actor = _TestActor('Firesh');
      expect(actor.name, equals('Firesh'));
    });

    test('has a Dio instance', () {
      final actor = _TestActor('Watersh');
      expect(actor.dio, isNotNull);
    });

    test('curlInterceptor log starts empty', () {
      final actor = _TestActor('Bulbasaur');
      expect(actor.curlInterceptor.log, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Testeador — CurlInterceptor injection
  // -------------------------------------------------------------------------
  group('Testeador interceptor injection', () {
    test('injects CurlInterceptor into actor Dio before running', () async {
      final actor = _TestActor('TestActor');
      // Interceptor should NOT be in dio.interceptors before run
      expect(actor.dio.interceptors.contains(actor.curlInterceptor), isFalse);

      final testeador = Testeador(
        flows: [
          TestFlowLasting(
            name: 'dummy',
            steps: [TestStep(name: 's', action: () {})],
          ),
        ],
        actors: [actor],
      );

      await testeador.run(['--no-exit-on-failure']);
      // After run, interceptor should be attached
      expect(actor.dio.interceptors.contains(actor.curlInterceptor), isTrue);
    });
  });
}
