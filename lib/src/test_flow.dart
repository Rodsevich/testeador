import 'fixture.dart';
import 'test_step.dart';

/// {@template test_flow}
/// A group of test steps and fixtures that are executed sequentially.
/// {@endtemplate}
class TestFlow {
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
