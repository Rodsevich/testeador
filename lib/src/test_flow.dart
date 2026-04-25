import 'package:testeador/src/fixture.dart';
import 'package:testeador/src/test_step.dart';

/// {@template test_flow}
/// A named, ordered sequence of [TestStep]s with an optional [Fixture].
///
/// The fixture (if provided) is loaded before steps run and disposed after,
/// even on failure.
/// {@endtemplate}
sealed class TestFlow {
  /// {@macro test_flow}
  const TestFlow({
    required this.name,
    required this.steps,
    this.fixture,
    this.tags = const {},
    this.description,
  });

  /// Human-readable name for this flow.
  final String name;

  /// Optional description.
  final String? description;

  /// Steps executed sequentially.
  final List<TestStep> steps;

  /// Optional fixture loaded before steps and disposed after.
  final Fixture<dynamic>? fixture;

  /// Tags for filtering (e.g., `{'smoke', 'pokemon'}`).
  final Set<String> tags;
}

/// {@template test_flow_lasting}
/// A [TestFlow] whose side effects intentionally persist after execution.
///
/// Use for tests where leaving state altered is expected and safe.
/// {@endtemplate}
class TestFlowLasting extends TestFlow {
  /// {@macro test_flow_lasting}
  const TestFlowLasting({
    required super.name,
    required super.steps,
    super.fixture,
    super.tags,
    super.description,
  });
}

/// {@template test_flow_transient}
/// A [TestFlow] that should not leave lasting state changes.
///
/// *note*: Rollback mechanism not yet implemented.
/// Candidate approaches:
///   1. Transaction scope callback on `Fixture` (database-agnostic).
///   2. RollbackStrategy pattern (see git history for prior art).
/// For now, this class is a marker type only — no rollback is performed.
/// {@endtemplate}
class TestFlowTransient extends TestFlow {
  /// {@macro test_flow_transient}
  const TestFlowTransient({
    required super.name,
    required super.steps,
    super.fixture,
    super.tags,
    super.description,
  });
}
