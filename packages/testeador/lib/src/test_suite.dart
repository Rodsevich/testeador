import 'package:flutter_test/flutter_test.dart';
import 'package:testeador_base/testeador_base.dart';
import 'package:testeador/src/fixture_entry.dart';
import 'package:testeador/src/registrable_flow.dart';
import 'package:testeador/src/ui_actor.dart';

/// {@template test_suite}
/// The orchestrator that groups one or more [Fixture] instances and
/// coordinates their lifecycle and flow execution within `package:test`'s
/// `group()` structure.
///
/// Call [register] inside your test file's `main()` function to register all
/// fixtures and flows with `dart test`. No custom runner is required.
///
/// ## Responsibilities
///
/// - Calls `fixture.setUp()` inside `setUpAll()`.
/// - Calls `fixture.tearDown()` inside `tearDownAll()`.
/// - Registers each [RegistrableFlow] (backend `TestFlow`s as a `group()`
///   with individual `test()` calls per step; `UiTestFlow`s as a single
///   `testWidgets`).
/// - Runs transient flows first within each fixture entry; every other flow
///   (lasting, UI) follows in declaration order.
///
/// ## Example
///
/// ```dart
/// void main() {
///   TestSuite(
///     name: 'UserRepository',
///     entries: [
///       TestSuite.entry(
///         fixture: UserFixture(),
///         flows: [
///           TestFlowTransient(name: 'fetches user by id', steps: [...]),
///           LastingTestFlow(name: 'creates a new user', steps: [...]),
///         ],
///       ),
///     ],
///   ).register();
/// }
/// ```
/// {@endtemplate}
final class TestSuite {
  /// {@macro test_suite}
  const TestSuite({required this.name, required this.entries});

  /// Human-readable name for the top-level `group()` in test output.
  final String name;

  /// The list of fixture entries to register.
  final List<FixtureEntry<dynamic>> entries;

  /// Creates a [FixtureEntry] pairing [fixture] with [flows].
  ///
  /// Use this factory method to build entries for [TestSuite.entries]:
  ///
  /// ```dart
  /// TestSuite.entry(
  ///   fixture: UserFixture(),
  ///   flows: [fetchUserFlow, createUserFlow],
  /// )
  /// ```
  static FixtureEntry<T> entry<T>({
    required Fixture<T> fixture,
    required List<RegistrableFlow<T>> flows,
    List<UiActor<T>> actors = const [],
  }) {
    return FixtureEntry<T>(fixture: fixture, flows: flows, actors: actors);
  }

  /// Registers all fixture entries with `package:test`.
  ///
  /// Call this inside your test file's `main()` function. Each entry is
  /// wrapped in a `group()` named after the fixture's runtime type, with
  /// `setUpAll`/`tearDownAll` managing the fixture lifecycle.
  void register() {
    group(name, () {
      for (final entry in entries) {
        entry.register();
      }
    });
  }
}
