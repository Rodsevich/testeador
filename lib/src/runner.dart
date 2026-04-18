import 'test_flow.dart';

/// {@template test_runner}
/// A runner that executes [TestFlow]s sequentially.
/// {@endtemplate}
class TestRunner {
  /// {@macro test_runner}
  const TestRunner({
    required this.flows,
  });

  /// The flows to be executed.
  final List<TestFlow> flows;

  /// Executes the flows, optionally filtered by [tags].
  ///
  /// If [failFast] is true (default), execution stops on the first flow failure.
  Future<void> run({Set<String>? tags, bool failFast = true}) async {
    final flowsToRun = tags == null || tags.isEmpty
        ? flows
        : flows.where((flow) => flow.tags.any(tags.contains)).toList();

    print('Starting test execution...');
    print('Total flows to run: ${flowsToRun.length}');

    for (final flow in flowsToRun) {
      print('\nRunning Flow: ${flow.name}');
      if (flow.description != null) {
        print('Description: ${flow.description}');
      }

      final loadedFixtures = [];
      try {
        // Load fixtures
        for (final fixture in flow.fixtures) {
          print('  Loading fixture: ${fixture.runtimeType}');
          loadedFixtures.add(await fixture.load());
        }

        // Execute steps
        for (final step in flow.steps) {
          print('  Executing Step: ${step.name}');
          await step.execute();
        }
        print('Flow completed successfully: ${flow.name}');
      } catch (e, stackTrace) {
        print('Flow failed: ${flow.name}');
        print('Error: $e');
        print('Stack trace: $stackTrace');
        if (failFast) rethrow;
      } finally {
        // Dispose fixtures in reverse order
        for (var i = loadedFixtures.length - 1; i >= 0; i--) {
          await flow.fixtures[i].dispose(loadedFixtures[i]);
        }
      }
    }

    print('\nAll flows completed successfully.');
  }
}
