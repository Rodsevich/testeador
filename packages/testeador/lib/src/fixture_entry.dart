import 'package:flutter_test/flutter_test.dart';
import 'package:testeador_base/testeador_base.dart';
import 'package:testeador/src/registrable_flow.dart';
import 'package:testeador/src/ui_actor.dart';

/// Internal value object pairing a [Fixture] with its associated
/// [RegistrableFlow]s.
///
/// This type is an implementation detail of `TestSuite` and is not part of
/// the public API. Users create instances via `TestSuite.entry`.
///
/// The [register] method encapsulates type-safe execution so that `TestSuite`
/// can call it without needing to know the concrete type parameter [T].
///
/// Internally, [_TypedFixtureEntry] holds the typed fixture and flows and
/// overrides [register] to perform type-safe orchestration.
abstract class FixtureEntry<T> {
  /// Creates a [FixtureEntry] pairing [fixture] with [flows], optionally
  /// executed by [actors].
  ///
  /// [actors] is required (non-empty) when [flows] contains any
  /// [ActorDrivenFlow] (e.g. `UiTestFlow`): each of those flows is
  /// registered **once per actor** — the geometric combination
  /// `fixture × actors × flows`. Backend flows ignore [actors].
  const factory FixtureEntry({
    required Fixture<T> fixture,
    required List<RegistrableFlow<T>> flows,
    List<UiActor<T>> actors,
  }) = _TypedFixtureEntry<T>;

  /// The fixture that provides the context object [T] (the *world*).
  Fixture<T> get fixture;

  /// The ordered list of flows to run against the fixture's context.
  List<RegistrableFlow<T>> get flows;

  /// The actors that execute the [ActorDrivenFlow]s of this entry.
  List<UiActor<T>> get actors;

  /// Registers the fixture lifecycle and all associated flows with
  /// `package:test` inside a `group` named after the fixture's runtime type.
  ///
  /// - Calls `setUpAll` to invoke [Fixture.setUp] then [Fixture.build].
  /// - Runs transient flows before lasting flows to prevent state pollution.
  /// - Each flow receives the context produced by [Fixture.build] and the
  ///   fixture's optional [Fixture.transactionScope].
  /// - Calls `tearDownAll` to invoke [Fixture.tearDown].
  void register();
}

/// Concrete typed implementation of [FixtureEntry].
///
/// Holds the fixture and flows with their concrete type [T] preserved,
/// ensuring type-safe context passing to flows even when stored as
/// `FixtureEntry<dynamic>` in a list.
final class _TypedFixtureEntry<T> implements FixtureEntry<T> {
  const _TypedFixtureEntry({
    required this.fixture,
    required this.flows,
    this.actors = const [],
  });

  @override
  final Fixture<T> fixture;

  @override
  final List<RegistrableFlow<T>> flows;

  @override
  final List<UiActor<T>> actors;

  @override
  void register() {
    final actorDriven = flows.whereType<ActorDrivenFlow<T>>().toList();
    if (actorDriven.isNotEmpty && actors.isEmpty) {
      throw ArgumentError(
        'Entry for ${fixture.runtimeType} contains actor-driven flows '
        '(${actorDriven.map((f) => '"${f.name}"').join(', ')}) but no '
        'actors. Pass actors to TestSuite.entry(actors: [...]).',
      );
    }

    group(fixture.runtimeType.toString(), () {
      // Declaration order, as written. The pure-Dart contract flows of
      // `testeador_base` (TestFlowLasting/TestFlowTransient) are NOT handled
      // here: those are data classes executed by `Testeador`, and mixing both
      // execution models in one entry buys nothing. This entry combines UI
      // flows — fixture × actors × flows.
      final orderedFlows = flows;

      // Use a single-element list to hold the context so the closure captures
      // a reference that can be mutated after setUpAll runs.
      final contextHolder = <T>[];

      setUpAll(() async {
        await fixture.setUp();
        contextHolder.add(await fixture.load());
      });

      // Pass a getter so each test body reads context lazily after setUpAll
      // has populated it, rather than capturing the uninitialized value at
      // group-registration time. Actor-driven flows register once per actor
      // (fixture × actors × flows); the rest register once.
      for (final flow in orderedFlows) {
        if (flow is ActorDrivenFlow<T>) {
          for (final actor in actors) {
            flow.runAs(actor, () => contextHolder.first);
          }
        } else {
          flow.run(
            () => contextHolder.first,
            transactionScope: fixture.transactionScope,
          );
        }
      }

      tearDownAll(() async {
        await fixture.tearDown();
      });
    });
  }
}
