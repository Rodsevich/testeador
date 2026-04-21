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

      final flow = TestFlowTransient(
        name: 'Flow 1',
        rollbackStrategy: RollbackStrategyCustom(revertAction: () async {}),
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

      final flow1 = TestFlowTransient(
        name: 'Flow 1',
        rollbackStrategy: RollbackStrategyCustom(revertAction: () async {}),
        tags: {'tag1'},
        steps: [TestStep(name: 'S1', action: () => executedFlows.add('flow1'))],
      );
      final flow2 = TestFlowTransient(
        name: 'Flow 2',
        rollbackStrategy: RollbackStrategyCustom(revertAction: () async {}),
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
      final flow = TestFlowTransient(
        name: 'Flow with Fixture',
        rollbackStrategy: RollbackStrategyCustom(revertAction: () async {}),
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
      final flow = TestFlowTransient(
        name: 'Failing Flow',
        rollbackStrategy: RollbackStrategyCustom(revertAction: () async {}),
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

      final flow = TestFlowTransient(
        name: 'Fixture Failure Flow',
        rollbackStrategy: RollbackStrategyCustom(revertAction: () async {}),
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

      final flow1 = TestFlowTransient(
        name: 'Failing Flow',
        rollbackStrategy: RollbackStrategyCustom(revertAction: () async {}),
        steps: [
          TestStep(
            name: 'Fail',
            action: () => throw Exception('Failure'),
          ),
        ],
      );
      final flow2 = TestFlowTransient(
        name: 'Succeeding Flow',
        rollbackStrategy: RollbackStrategyCustom(revertAction: () async {}),
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

    test('executes revertAction when TestFlowTransient fails', () async {
      var revertExecuted = false;

      final flow = TestFlowTransient(
        name: 'Failing Flow',
        steps: [
          TestStep(
            name: 'Fail',
            action: () => throw Exception('Failure'),
          ),
        ],
        rollbackStrategy: RollbackStrategyCustom(
          revertAction: () async {
            revertExecuted = true;
          },
        ),
      );

      final runner = TestRunner(flows: [flow]);

      try {
        await runner.run();
      } catch (_) {}

      expect(revertExecuted, isTrue);
    });

    test('executes TestFlowLasting and its steps', () async {
      final executionOrder = <String>[];

      final flow = TestFlowLasting(
        name: 'Lasting Flow',
        steps: [
          TestStep(
            name: 'Step 1',
            action: () => executionOrder.add('lasting_step1'),
          ),
        ],
      );

      final runner = TestRunner(flows: [flow]);
      await runner.run();

      expect(executionOrder, equals(['lasting_step1']));
    });

    test('executes a complete CRUD flow successfully', () async {
      // Let's simulate an API service using a local Map.
      final mockDatabase = <String, Map<String, dynamic>>{};
      String? createdId;

      final flow = TestFlowTransient(
        name: 'Simulated API CRUD Flow',
        rollbackStrategy: RollbackStrategyCustom(
          revertAction: () async {
            // In a real scenario, this would clean up the DB
            if (createdId != null) {
              mockDatabase.remove(createdId);
            }
          },
        ),
        steps: [
          TestStep(
            name: 'Create',
            action: () async {
              createdId = 'mock_id_123';
              mockDatabase[createdId!] = {
                'name': 'Pokemon Team',
                'pokemons': ['pikachu'],
              };
            },
          ),
          TestStep(
            name: 'Read',
            action: () async {
              final team = mockDatabase[createdId!];
              if (team == null) throw Exception('Team not found');
              final pokemons = team['pokemons'] as List;
              if (pokemons.length != 1 || pokemons[0] != 'pikachu') {
                throw Exception('Team data mismatch');
              }
            },
          ),
          TestStep(
            name: 'Update',
            action: () async {
              mockDatabase[createdId!]!['pokemons'] = ['pikachu', 'bulbasaur'];
            },
          ),
          TestStep(
            name: 'Read after Update',
            action: () async {
              final team = mockDatabase[createdId!];
              final pokemons = team!['pokemons'] as List;
              if (pokemons.length != 2) throw Exception('Update failed');
            },
          ),
          TestStep(
            name: 'Delete (Simulated via failure to trigger rollback)',
            action: () async {
              // We intentionally throw here to ensure the runner triggers the
              // rollbackStrategy which cleans up the mockDatabase.
              throw Exception('Intentional failure to trigger cleanup');
            },
          ),
        ],
      );

      final runner = TestRunner(flows: [flow]);

      try {
        await runner.run();
      } catch (e) {
        // Exception caught, rollback should have happened.
      }

      // Assert that rollback cleaned up the created ID.
      expect(mockDatabase.containsKey(createdId), isFalse);
    });
  });
}
