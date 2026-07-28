import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:testeador_base/testeador_base.dart';
import 'package:testeador/src/registrable_flow.dart';
import 'package:testeador/src/ui_actor.dart';
import 'package:testeador_base/evidence.dart';
import 'package:testeador/src/evidence_recorder.dart';
import 'package:testeador/src/ui_test_step.dart';
import 'package:testeador/src/viewport_preset.dart';

/// {@template ui_test_flow}
/// A named sequence of UI steps that runs the fixture's app headlessly with
/// `flutter test`, photographing the UI **automatically at the end of every
/// step** and scoring each capture against its versioned baseline.
///
/// The flow [name] is the *scenario* (the artifact folder). The flow is
/// **actor-driven** ([ActorDrivenFlow]): the `Fixture` builds the *world*
/// `T` once, each [Actor] opens its own *session* over it, and
/// `TestSuite.entry(fixture: ..., actors: [...], flows: [...])` registers
/// the geometric combination — one fixture × M actors × N flows = M×N runs,
/// each with an independent capture set (`checkout/comprador-*`,
/// `checkout/visitante-*`) and its own baselines.
///
/// ## Execution model
///
/// The whole flow registers as **one `testWidgets`** (steps share the
/// mounted app; re-running previous steps per test would be O(n²)). Per-step
/// granularity lives in the run manifest, the structural source of truth.
///
/// - A step's exception marks the run red, photographs the crash state
///   (`~crash`) and records the remaining steps as `skipped` — the manifest
///   stays complete for the AI judge.
/// - **Visual drift never fails the run**: captures are scored (log-scaled
///   `!` markers) and judged post-run by an AI agent
///   (see `docs/verdict-agent.md`).
/// - Slug collisions between step descriptions fail at construction time.
///
/// `UiTestFlow` implements [ActorDrivenFlow] (it is *not* a `TestFlow`
/// subclass) and takes no part in the transient/lasting distinction.
/// {@endtemplate}
final class UiTestFlow<T> implements ActorDrivenFlow<T> {
  /// {@macro ui_test_flow}
  ///
  /// Throws an [ArgumentError] at construction if two step descriptions
  /// slugify to the same value.
  UiTestFlow({
    required this.name,
    required this.steps,
    this.viewport = ViewportPreset.phone,
    this.config = defaultEvidenceConfig,
    this.patrolConfig = const PatrolTesterConfig(),
    EvidenceFileSystem fileSystem = const EvidenceFileSystem(),
  }) : _fs = fileSystem {
    ensureUniqueSlugs(steps.map((s) => s.description));
  }

  /// Scenario name: names the `testWidgets` and the artifact folder.
  @override
  final String name;

  /// Ordered steps; each one is photographed after its body completes.
  final List<UiTestStep<T>> steps;

  /// Viewport preset applied before mounting the app.
  final ViewportPreset viewport;

  /// Evidence capture configuration.
  final EvidenceConfig config;

  /// Configuration for the [PatrolTester] handed to step bodies.
  final PatrolTesterConfig patrolConfig;

  final EvidenceFileSystem _fs;

  /// Not supported: a [UiTestFlow] is actor-driven. Register it through
  /// `TestSuite.entry(fixture: ..., actors: [...], flows: [...])` or call
  /// [runAs] directly.
  @override
  Never run(
    dynamic Function() contextGetter, {
    Future<void> Function(Future<void> Function() body)? transactionScope,
  }) {
    throw StateError(
      'UiTestFlow "$name" is actor-driven: pass actors to TestSuite.entry '
      '(actors: [...]) or register it with runAs(actor, contextGetter).',
    );
  }

  /// Registers this flow as one `testWidgets` executed as [actor].
  @override
  void runAs(UiActor<T> actor, dynamic Function() contextGetter) {
    testWidgets('$name — ${actor.name}', (tester) async {
      await execute(tester, contextGetter() as T, actor: actor);
    });
  }

  /// Runs the flow body: opens [actor]'s session over the [world], mounts
  /// the app, executes each step, photographs it, and reconciles orphaned
  /// baselines at the end.
  ///
  /// Exposed for testing the crash/skip semantics without registering a
  /// failing `testWidgets`.
  @visibleForTesting
  Future<void> execute(
    WidgetTester tester,
    T world, {
    required UiActor<T> actor,
  }) async {
    final recorder = EvidenceRecorder(
      scenario: name,
      actor: actor.name,
      config: config,
      viewport: viewport,
      fileSystem: _fs,
    );
    final $ = PatrolTester(tester: tester, config: patrolConfig);

    final app = await tester.runAsync(() => actor.session(world));
    await recorder.pump(tester, app!(), wrapInMaterialApp: false);

    Object? stepFailure;
    StackTrace? stepStackTrace;
    try {
      for (final step in steps) {
        if (stepFailure != null) {
          recorder.markSkipped(name: step.description, intent: step.intent);
          continue;
        }
        try {
          await step.body(world, $);
          await recorder.photo(
            tester,
            name: step.description,
            intent: step.intent,
          );
        } on EvidenceCaptureException {
          // Harness failure (I/O, rasterization): not an app failure —
          // surface immediately and untouched.
          rethrow;
        } on Object catch (error, stackTrace) {
          stepFailure = error;
          stepStackTrace = stackTrace;
          await recorder.photoCrash(
            tester,
            name: step.description,
            intent: step.intent,
            exception: error,
          );
        }
      }
    } finally {
      recorder.reconcileOrphans();
    }
    if (stepFailure != null) {
      Error.throwWithStackTrace(stepFailure, stepStackTrace!);
    }
  }
}
