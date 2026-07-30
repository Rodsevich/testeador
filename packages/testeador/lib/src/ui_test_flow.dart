import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:path/path.dart' as p;
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
    this.knownDefects = const {},
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

  /// Defectos **ya conocidos** de la app que no deben poner el flujo en rojo:
  /// substring del error → por qué se tolera.
  ///
  /// Mismo principio que "el drift nunca falla la corrida": un defecto visual
  /// hay que *documentarlo*, no convertirlo en un test rojo sin foto. Un
  /// overflow pinta su franja rayada y un `InkWell` sin `Material` deja su
  /// hueco: la captura muestra el problema, que es más accionable que un stack
  /// trace. Además estos errores se re-disparan en cada pump, así que la
  /// tolerancia tiene que cubrir el flujo entero y no un body.
  ///
  /// Hay que **nombrar cada defecto** — no hay comodín. Un mapa vacío (el
  /// default) no tolera nada, y cualquier error no listado sigue haciendo
  /// fallar el paso: si esto fuera un colador escondería justo lo que la suite
  /// existe para encontrar. El valor de cada entrada es la razón, y se imprime
  /// al terminar para que nadie se olvide de que están ahí.
  final Map<String, String> knownDefects;

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

    // Enchufar el interceptor antes de que el actor abra su sesión, igual que
    // hace `Testeador` con los flujos de contrato: sin esto el log queda vacío
    // y el dump de curls al fallar no tendría nada que volcar.
    if (!actor.dio.interceptors.contains(actor.curlInterceptor)) {
      actor.dio.interceptors.add(actor.curlInterceptor);
    }

    final previousOnError = FlutterError.onError;
    final tolerated = <String, int>{};
    if (knownDefects.isNotEmpty) {
      FlutterError.onError = (details) {
        final text = details.exceptionAsString();
        for (final pattern in knownDefects.keys) {
          if (text.contains(pattern)) {
            tolerated[pattern] = (tolerated[pattern] ?? 0) + 1;
            return;
          }
        }
        previousOnError?.call(details);
      };
    }

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
          _dumpCurls(recorder, actor, step.description);
          await recorder.photoCrash(
            tester,
            name: step.description,
            intent: step.intent,
            exception: error,
          );
        }
      }
    } finally {
      if (knownDefects.isNotEmpty) {
        FlutterError.onError = previousOnError;
        for (final entry in tolerated.entries) {
          debugPrint(
            '[evidence] "$name": ${entry.value}× "${entry.key}" tolerado — '
            '${knownDefects[entry.key]}. La captura lo muestra.',
          );
        }
      }
      recorder.reconcileOrphans();
      // Desmontar el árbol y avanzar el reloj un tick. Las apps reales dejan
      // timers vivos (streams de la base, relojes, animaciones) y el binding
      // de flutter_test falla el test con "A Timer is still pending even after
      // the widget tree was disposed" aunque los pasos hayan pasado. El
      // desmontaje corre los `dispose()` y el pump con duración dispara los
      // `Timer.run` con que cierran esos streams.
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      } on Object {
        // El árbol ya podía estar inconsistente por el fallo del paso: la
        // evidencia ya está escrita y esa excepción es la que importa.
      }
    }
    if (stepFailure != null) {
      Error.throwWithStackTrace(stepFailure, stepStackTrace!);
    }
  }

  /// Vuelca los curls del actor cuando un paso falla, y los adjunta al paso en
  /// el manifest.
  ///
  /// Es el input #4 del juez (`docs/verdict-agent.md`): correlacionar lo que
  /// hizo el backend con lo que muestra la pantalla, justo cuando importa. Un
  /// actor que no llama APIs no escribe nada.
  ///
  /// Vuelca **toda** la traza acumulada, no sólo la del paso que explotó: lo
  /// que hizo la sesión al abrirse (un login, un seed remoto) suele ser
  /// justamente lo que explica el fallo, y recortarla escondería la causa.
  void _dumpCurls(EvidenceRecorder recorder, UiActor<T> actor, String step) {
    final log = actor.curlInterceptor.log;
    if (log.isEmpty) return;
    final relative = p.join(
      'http',
      '${slugify(actor.name)}-${slugify(step)}.curl',
    );
    try {
      _fs.writeStringAtomic(
        p.join(recorder.runDir, relative),
        '${log.join('\n\n')}\n',
      );
    } on Object {
      // La evidencia visual del crash vale más que sus curls: si el disco
      // falla acá, no se tapa la excepción del paso.
      return;
    }
    recorder.attach(step: step, type: 'http', file: relative);
  }
}
