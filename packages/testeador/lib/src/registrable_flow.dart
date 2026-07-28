import 'package:testeador/src/ui_actor.dart';
import 'package:testeador_base/testeador_base.dart';

/// {@template registrable_flow}
/// Minimal contract shared by every flow `TestSuite`/`FixtureEntry` can
/// register: a [name] and a [run] method that registers the flow's tests
/// with the test framework.
///
/// Implemented by `TestFlow` (backend flows: `TestFlowTransient`,
/// `LastingTestFlow`) and by `UiTestFlow` (UI evidence flows). `UiTestFlow`
/// is **not** a `TestFlow` subclass — its steps carry a different record
/// shape (`intent` + a two-parameter body), and Dart records have no width
/// subtyping — so this interface is the shared seam instead of inheritance.
/// {@endtemplate}
///
/// Ordering within a `FixtureEntry`: `TestFlowTransient`s run first, every
/// other flow (lasting, UI) follows in declaration order.
abstract interface class RegistrableFlow<T> {
  /// Human-readable identifier shown in test output.
  String get name;

  /// Registers this flow's tests with the test framework.
  ///
  /// [contextGetter] returns the fixture context, lazily (called inside test
  /// bodies, after `setUpAll` has populated it). It is deliberately
  /// `dynamic Function()` — not `T Function()`: `TestSuite` stores entries
  /// as `FixtureEntry<dynamic>`, so downward inference types the getter as
  /// `dynamic` at the call site; a typed parameter would fail the runtime
  /// covariance check for every suite built through `TestSuite.entry`.
  /// Implementations cast the value to [T].
  ///
  /// [transactionScope] optionally wraps bodies in a rollback scope — flows
  /// that have no use for it simply ignore it.
  void run(
    dynamic Function() contextGetter, {
    Future<void> Function(Future<void> Function() body)? transactionScope,
  });
}

/// {@template actor_driven_flow}
/// A [RegistrableFlow] whose runs are performed **by an [Actor]** over the
/// fixture-built world: `FixtureEntry` registers it once per actor
/// (`fixture × actors × flows`), never through [RegistrableFlow.run].
///
/// Implemented by `UiTestFlow`. Backend flows (`TestFlow`) are not
/// actor-driven — they exercise the world directly, below any session.
/// {@endtemplate}
abstract interface class ActorDrivenFlow<T> implements RegistrableFlow<T> {
  /// Registers this flow's tests executed as [actor].
  ///
  /// See [RegistrableFlow.run] for the [contextGetter] contract.
  void runAs(
    UiActor<T> actor,
    dynamic Function() contextGetter,
  );
}
