import 'fixture.dart';
import 'test_step.dart';

/// The base strategy for rolling back changes made by a [TestFlowTransient].
///
/// Consumers can extend this class to provide custom rollback implementations.
abstract class RollbackStrategy {
  const RollbackStrategy();

  /// Executes the rollback mechanism when the flow fails.
  ///
  /// Provide [reloadFixtures] if the strategy needs to recreate fixtures
  /// after wiping the state (e.g., [RollbackStrategyNukeBd]).
  Future<void> execute({
    required Future<void> Function() reloadFixtures,
  });
}

/// Indicates that operations are executed within a transaction that will be
/// intentionally failed at the end to trigger a database rollback.
final class RollbackStrategyTransaction extends RollbackStrategy {
  const RollbackStrategyTransaction({required this.triggerRollback});

  /// The action to trigger the transaction failure or explicit rollback.
  final Future<void> Function() triggerRollback;

  @override
  Future<void> execute({
    required Future<void> Function() reloadFixtures,
  }) async {
    await triggerRollback();
  }
}

/// Indicates that operations will include a specific header, notifying the backend
/// that they are intended for testing and should be rolled back or treated ephemerally.
final class RollbackStrategyCustomHeader extends RollbackStrategy {
  const RollbackStrategyCustomHeader({
    required this.headerName,
    required this.headerValue,
  });

  final String headerName;
  final String headerValue;

  @override
  Future<void> execute({
    required Future<void> Function() reloadFixtures,
  }) async {
    // Backend handles the ephemeral state via headers.
    // No explicit action needed on failure from the runner's side.
  }
}

/// Executes an action to delete the database and, if necessary, recreate it using fixtures.
final class RollbackStrategyNukeBd extends RollbackStrategy {
  const RollbackStrategyNukeBd({required this.nukeAction});

  /// The action that drops or clears the database.
  final Future<void> Function() nukeAction;

  @override
  Future<void> execute({
    required Future<void> Function() reloadFixtures,
  }) async {
    await nukeAction();
    await reloadFixtures();
  }
}

/// A generic strategy for providing a custom fallback/revert action.
final class RollbackStrategyCustom extends RollbackStrategy {
  const RollbackStrategyCustom({required this.revertAction});

  final Future<void> Function() revertAction;

  @override
  Future<void> execute({
    required Future<void> Function() reloadFixtures,
  }) async {
    await revertAction();
  }
}

/// {@template test_flow}
/// Sequentially chains a series of [TestStep]s to form a complete integration flow.
/// {@endtemplate}
abstract class TestFlow {
  /// {@macro test_flow}
  const TestFlow({
    required this.name,
    required this.steps,
    this.fixtures = const [],
    this.tags = const {},
    this.description,
  });

  /// The name of the test flow.
  final String name;

  /// A description of what this flow tests.
  final String? description;

  /// The steps that make up this flow.
  final List<TestStep> steps;

  /// Fixtures that should be loaded before the flow starts.
  final List<Fixture<dynamic>> fixtures;

  /// Tags associated with this flow for filtering.
  final Set<String> tags;
}

/// {@template test_flow_transient}
/// A flow that should not alter the final state of the database.
///
/// When executed successfully, the steps themselves should revert or delete
/// any changes they made. If execution fails, the [rollbackStrategy] is triggered.
///
/// Revert Mechanisms for failures:
/// 1. [rollbackStrategy]: A strategy pattern implementation used to clean up
///    the database state.
/// 2. [Fixture.dispose]: Any fixtures used will still be disposed of in reverse
///    order, even on failure, providing a secondary cleanup mechanism.
/// {@endtemplate}
class TestFlowTransient extends TestFlow {
  /// {@macro test_flow_transient}
  const TestFlowTransient({
    required super.name,
    required super.steps,
    required this.rollbackStrategy,
    super.fixtures,
    super.tags,
    super.description,
  });

  /// The strategy to use for reverting state when the flow fails.
  ///
  /// The type system and class design inherently assert that exactly ONE
  /// strategy can be provided per transient flow.
  final RollbackStrategy rollbackStrategy;
}

/// {@template test_flow_lasting}
/// A flow whose changes can remain in the database without issues.
///
/// These flows are typically used for seeding data, initial configurations,
/// or operations where leaving the state altered is expected and safe.
/// {@endtemplate}
class TestFlowLasting extends TestFlow {
  /// {@macro test_flow_lasting}
  const TestFlowLasting({
    required super.name,
    required super.steps,
    super.fixtures,
    super.tags,
    super.description,
  });
}
