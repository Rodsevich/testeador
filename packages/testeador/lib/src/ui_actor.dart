import 'package:flutter/widgets.dart';
import 'package:testeador_base/testeador_base.dart';

/// {@template ui_actor}
/// The **user** that performs a UI flow: a persona with an initialized
/// session, distinct from the world its `Fixture` prepared.
///
/// The separation of responsibilities is deliberate:
///
/// - A `Fixture<T>` pre-populates the **world** — database records,
///   configuration, feature flags — and produces the typed context `T`.
/// - A [UiActor] opens a **session** on that world ([session] returns the app
///   builder, already logged in as this persona).
/// - A `UiTestFlow<T>` tells the **story** the actor performs.
///
/// They combine geometrically: one fixture × M actors × N flows = M×N runs,
/// each with its own evidence set (`<scenario>/<actor>-…`) and its own
/// baselines, without re-seeding the world per persona.
///
/// ## Networking is derivative
///
/// A [UiActor] **is** an [Actor], so it inherits the instrumented [Actor.dio]
/// and its [Actor.curlInterceptor]. You normally never touch them: the point
/// is that traffic is being recorded all along, so when a UI step fails the
/// recorder can dump the curls next to the crash capture and the judge can
/// correlate what the backend did with what the screen showed. A persona that
/// never calls an API pays nothing for it.
///
/// ## Example
///
/// ```dart
/// final class Comprador extends UiActor<SuperWorld> {
///   Comprador() : super(name: 'comprador');
///
///   @override
///   Future<Widget Function()> session(SuperWorld world) async {
///     final sesion = await world.auth.login('comprador@super.com');
///     return () => SuperApp(sesion: sesion);
///   }
/// }
/// ```
/// {@endtemplate}
abstract class UiActor<T> extends Actor {
  /// {@macro ui_actor}
  UiActor({required super.name, super.dio, super.redactHeaders});

  /// Opens this actor's session over the fixture-built [world] and returns
  /// the **app builder** to mount — a fresh widget tree per call, already
  /// authenticated and configured as this persona.
  Future<Widget Function()> session(T world);
}
