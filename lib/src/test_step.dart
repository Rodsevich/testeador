import 'dart:async';

/// {@template test_step}
/// A single named action within a `TestFlow`.
///
/// The [action] is a zero-argument async callback. Context (actors, fixtures,
/// repositories) is captured via closure at the call site.
/// {@endtemplate}
class TestStep {
  /// {@macro test_step}
  const TestStep({
    required this.name,
    required this.action,
    this.description,
  });

  /// Short name shown in output (maps to a `test()` label).
  final String name;

  /// Optional longer description.
  final String? description;

  /// The async action to execute.
  final FutureOr<void> Function() action;

  /// Executes the step.
  Future<void> execute() async => action();
}
