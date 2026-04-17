import 'package:test/test.dart';
import 'package:testeador/testeador.dart';

class MockFixture extends Fixture<int> {
  int loadCount = 0;
  int disposeCount = 0;

  @override
  Future<int> load() async {
    loadCount++;
    return 42;
  }

  @override
  Future<void> dispose(int data) async {
    disposeCount++;
  }
}

class FailingFixture extends Fixture<int> {
  @override
  Future<int> load() async => throw Exception('Load failure');
}

void main() {
  group('TestRunner', () {
    test('executes flows and steps sequentially', () async {
      final executionOrder = <String>[];

      final flow = TestFlow(
        name: 'Flow 1',
        steps: [
          TestStep(
            name: 'Step 1',
            action: () => executionOrder.add('step1'),
          ),
          TestStep(
            name: 'Step 2',
            action: () => executionOrder.add('step2'),
          ),
        ],
      );

      final runner = TestRunner(flows: [flow]);
      await runner.run();

      expect(executionOrder, equals(['step1', 'step2']));
    });

    test('filters flows by tags', () async {
      final executedFlows = <String>[];

      final flow1 = TestFlow(
        name: 'Flow 1',
        tags: {'tag1'},
        steps: [TestStep(name: 'S1', action: () => executedFlows.add('flow1'))],
      );
      final flow2 = TestFlow(
        name: 'Flow 2',
        tags: {'tag2'},
        steps: [TestStep(name: 'S2', action: () => executedFlows.add('flow2'))],
      );

      final runner = TestRunner(flows: [flow1, flow2]);

      await runner.run(tags: {'tag1'});
      expect(executedFlows, equals(['flow1']));

      executedFlows.clear();
      await runner.run(tags: {'tag2'});
      expect(executedFlows, equals(['flow2']));
    });

    test('manages fixture lifecycle', () async {
      final fixture = MockFixture();
      final flow = TestFlow(
        name: 'Flow with Fixture',
        fixtures: [fixture],
        steps: [TestStep(name: 'Step', action: () {})],
      );

      final runner = TestRunner(flows: [flow]);
      await runner.run();

      expect(fixture.loadCount, equals(1));
      expect(fixture.disposeCount, equals(1));
    });

    test('disposes fixtures even if steps fail', () async {
      final fixture = MockFixture();
      final flow = TestFlow(
        name: 'Failing Flow',
        fixtures: [fixture],
        steps: [
          TestStep(
            name: 'Failing Step',
            action: () => throw Exception('Test failure'),
          ),
        ],
      );

      final runner = TestRunner(flows: [flow]);

      try {
        await runner.run();
      } catch (_) {}

      expect(fixture.loadCount, equals(1));
      expect(fixture.disposeCount, equals(1));
    });

    test('handles fixture loading failure gracefully', () async {
      final fixture1 = MockFixture();
      final failingFixture = FailingFixture();
      final fixture2 = MockFixture();

      final flow = TestFlow(
        name: 'Fixture Failure Flow',
        fixtures: [fixture1, failingFixture, fixture2],
        steps: [TestStep(name: 'Step', action: () {})],
      );

      final runner = TestRunner(flows: [flow]);

      try {
        await runner.run();
      } catch (_) {}

      expect(fixture1.loadCount, equals(1));
      expect(fixture1.disposeCount, equals(1));
      expect(fixture2.loadCount, equals(0));
    });

    test('continues on failure if failFast is false', () async {
      final executedFlows = <String>[];

      final flow1 = TestFlow(
        name: 'Failing Flow',
        steps: [
          TestStep(
            name: 'Fail',
            action: () => throw Exception('Failure'),
          ),
        ],
      );
      final flow2 = TestFlow(
        name: 'Succeeding Flow',
        steps: [
          TestStep(
            name: 'Success',
            action: () => executedFlows.add('flow2'),
          ),
        ],
      );

      final runner = TestRunner(flows: [flow1, flow2]);

      await runner.run(failFast: false);

      expect(executedFlows, equals(['flow2']));
    });
  });
}
