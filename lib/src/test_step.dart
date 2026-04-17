import 'dart:async';

/// {@template test_step}
/// A single unit of a test flow.
/// {@endtemplate}
class TestStep {
  /// {@macro test_step}
  const TestStep({
    required this.name,
    required this.action,
    this.description,
  });

  /// The name of the test step.
  final String name;

  /// A description of what this step does.
  final String? description;

  /// The action to be performed in this step.
  final FutureOr<void> Function() action;

  /// Executes the test step.
  Future<void> execute() async {
    await action();
  }
}
