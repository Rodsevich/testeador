// QuestlineScenario sigue siendo el vocabulario de las suites existentes
// mientras dura la transición a dev_mate's Scenario (ver toScenario()).
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:dev_mate_client/dev_mate_client.dart'
    show Scenario, ScenarioStep;
import 'package:testeador/src/fixture.dart';
import 'package:testeador/src/live/questline_live_client.dart';
import 'package:testeador/src/test_step.dart';

/// {@template questline_scenario}
/// A declarative questline runtime state: a set of [signals] to apply and an
/// optional clock override (a liturgical hour name, a raw [clockMinutes], or an
/// ISO instant [clockIso]).
///
/// Scenarios are plain data so they can be reused across flows and fixtures.
/// {@endtemplate}
// La deprecación es deliberada en 0.x: marca el puente de la transición.
// ignore: remove_deprecations_in_breaking_versions
@Deprecated(
  'Usá el Scenario genérico de dev_mate (pasos {extension, args} '
  'cross-dominio + restoreSteps explícitos); este tipo queda como puente — '
  'convertí con toScenario().',
)
class QuestlineScenario {
  /// {@macro questline_scenario}
  // ignore: remove_deprecations_in_breaking_versions
  @Deprecated('Convertí con toScenario() hacia el Scenario de dev_mate.')
  const QuestlineScenario({
    this.name = 'scenario',
    this.signals = const <String, Object?>{},
    this.liturgicalHour,
    this.clockMinutes,
    this.clockIso,
  });

  /// Human-readable name, used in step/flow labels.
  final String name;

  /// Signals to set, keyed by signal name. Values keep their Dart type so the
  /// client can infer the contract `type` (bool/int/double/string/null).
  final Map<String, Object?> signals;

  /// Liturgical hour label to force the clock to, resolved against the
  /// app's clock presets in the dev_mate catalog (see
  /// [QuestlineLiveClient.forceLiturgicalHour]).
  final String? liturgicalHour;

  /// Raw minute-of-day (0..1439) to force the clock to.
  final int? clockMinutes;

  /// ISO-8601 instant to force the clock to.
  final String? clockIso;

  /// Example: only pin the clock to *Sexta*, no signal changes.
  static const QuestlineScenario sexta = QuestlineScenario(
    name: 'hora-sexta',
    liturgicalHour: 'sexta',
  );

  /// Example: a fresh Sunday novice — nothing unlocked yet.
  static const QuestlineScenario sundayNovice = QuestlineScenario(
    name: 'novicio-domingo',
    signals: <String, Object?>{
      'feria': 1,
      'openCount': 1,
      'personalityDone': 0,
      'unlockedOpusDiei': false,
      'unlockedOpusVita': false,
      'unlockedOpusLabor': false,
      'unlockedOpusConstantia': false,
      'unlockedOpusKalendarium': false,
    },
  );

  /// Example: every Opus unlocked.
  static const QuestlineScenario allUnlocked = QuestlineScenario(
    name: 'todo-desbloqueado',
    signals: <String, Object?>{
      'unlockedOpusDiei': true,
      'unlockedOpusVita': true,
      'unlockedOpusLabor': true,
      'unlockedOpusConstantia': true,
      'unlockedOpusKalendarium': true,
    },
  );

  /// Bridge to dev_mate's generic [Scenario]: signals become
  /// `ext.questline.setSignal` steps and the clock override becomes an
  /// `ext.dev_mate.clock.force` step. Restore is honest-and-explicit: only
  /// the clock is cleared (a signal write has no derivable inverse — restore
  /// them via the prior `dumpState`, as [QuestlineActor] does).
  ///
  /// Note: `liturgicalHour` labels resolve app-side; prefer `clockMinutes`/
  /// `clockIso` here (a pure-data scenario cannot read the catalog).
  Scenario toScenario() => Scenario(
    name: name,
    description: 'puente desde QuestlineScenario',
    steps: <ScenarioStep>[
      for (final entry in signals.entries)
        ScenarioStep('ext.questline.setSignal', <String, String>{
          'key': entry.key,
          'value': entry.value?.toString() ?? '',
          'type': switch (entry.value) {
            null => 'null',
            bool _ => 'bool',
            int _ => 'int',
            double _ => 'double',
            _ => 'string',
          },
        }),
      if (clockMinutes != null)
        ScenarioStep('ext.dev_mate.clock.force', <String, String>{
          'minutes': '$clockMinutes',
        })
      else if (clockIso != null)
        ScenarioStep('ext.dev_mate.clock.force', <String, String>{
          'iso': clockIso!,
        }),
    ],
    restoreSteps: <ScenarioStep>[
      if (clockMinutes != null || clockIso != null || liturgicalHour != null)
        const ScenarioStep('ext.dev_mate.clock.clear'),
    ],
  );
}

/// {@template questline_actor}
/// Reusable driver that prepares questline scenarios against a running app.
///
/// It is the questline sibling of `Actor`, but does **not** extend it: an
/// `Actor` is defined by its `Dio` HTTP transport, whereas this driver talks to
/// the app over the VM service through a [QuestlineLiveClient]. Keeping it
/// separate avoids saddling it with an unused `Dio`/cURL interceptor while
/// preserving the same `name`-plus-transport shape.
/// {@endtemplate}
class QuestlineActor {
  /// {@macro questline_actor}
  QuestlineActor({required this.name, required this.client});

  /// Convenience: builds an actor with a fresh client for the app at [wsUri].
  QuestlineActor.forApp(String wsUri, {this.name = 'questline'})
    : client = QuestlineLiveClient(wsUri: wsUri);

  /// Human-readable name for this driver (used in output).
  final String name;

  /// The transport used to reach the app's `ext.questline.*` extensions.
  final QuestlineLiveClient client;

  /// Applies [scenario] (signals then clock) and returns the app's `dumpState`
  /// snapshot taken **before** applying, so [restore] can undo it.
  Future<Map<String, dynamic>> apply(QuestlineScenario scenario) async {
    final prior = await client.dumpState();
    for (final entry in scenario.signals.entries) {
      await client.setSignal(entry.key, entry.value);
    }
    if (scenario.liturgicalHour != null) {
      await client.forceLiturgicalHour(scenario.liturgicalHour!);
    } else if (scenario.clockMinutes != null) {
      await client.forceHour(scenario.clockMinutes!);
    } else if (scenario.clockIso != null) {
      await client.forceClockIso(scenario.clockIso!);
    }
    return prior;
  }

  /// Undoes an [apply]: clears any forced clock and re-sets the signals that
  /// [scenario] touched back to their values in the [prior] snapshot.
  Future<void> restore(
    Map<String, dynamic> prior,
    QuestlineScenario scenario,
  ) async {
    final signals =
        (prior['signals'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    for (final key in scenario.signals.keys) {
      final entry = signals[key];
      if (entry is Map && entry['value'] != null) {
        await client.setSignal(
          key,
          entry['value'],
          type: entry['type'] as String?,
        );
      }
    }
    await client.clearClock();
  }
}

/// {@template questline_scenario_fixture}
/// A [Fixture] that applies a [QuestlineScenario] on [load] and restores the
/// prior state on [dispose] (unless [restore] is `false`).
///
/// Its loaded value is the [QuestlineLiveClient], so a flow's steps can keep
/// driving the runtime after setup.
/// {@endtemplate}
class QuestlineScenarioFixture extends Fixture<QuestlineLiveClient> {
  /// {@macro questline_scenario_fixture}
  QuestlineScenarioFixture({
    required this.actor,
    required this.scenario,
    this.restore = true,
  });

  /// Driver that applies/restores the scenario.
  final QuestlineActor actor;

  /// Scenario to apply.
  final QuestlineScenario scenario;

  /// Whether [dispose] should restore the prior state.
  final bool restore;

  Map<String, dynamic>? _prior;

  @override
  Future<QuestlineLiveClient> load() async {
    _prior = await actor.apply(scenario);
    return actor.client;
  }

  @override
  Future<void> dispose(QuestlineLiveClient data) async {
    if (restore && _prior != null) {
      await actor.restore(_prior!, scenario);
    }
  }
}

// -----------------------------------------------------------------------------
// TestStep helpers — drop these into a TestFlow's `steps` to configure the
// questline runtime as part of the flow.
// -----------------------------------------------------------------------------

/// A step that sets signal [key] to [value].
///
/// See [QuestlineLiveClient.setSignal].
TestStep setSignalStep(
  QuestlineLiveClient client,
  String key,
  Object? value, {
  String? type,
}) => TestStep(
  name: 'set signal $key=$value',
  action: () => client.setSignal(key, value, type: type),
);

/// A step that forces the clock to liturgical hour [liturgicalHour]
/// (e.g. `'sexta'`).
TestStep forceHourStep(QuestlineLiveClient client, String liturgicalHour) =>
    TestStep(
      name: 'force hour $liturgicalHour',
      action: () => client.forceLiturgicalHour(liturgicalHour),
    );

/// A step that releases a forced clock.
TestStep clearClockStep(QuestlineLiveClient client) => TestStep(
  name: 'clear forced clock',
  action: client.clearClock,
);

/// A step that reads the runtime state and fails (throws [StateError]) unless
/// signal [key] equals [expected] (compared as strings).
TestStep assertSignalStep(
  QuestlineLiveClient client,
  String key,
  Object? expected,
) => TestStep(
  name: 'assert signal $key==$expected',
  action: () async {
    final state = await client.dumpState();
    final signals = (state['signals'] as Map?)?.cast<String, dynamic>();
    final entry = signals?[key];
    final actual = entry is Map ? entry['value'] : null;
    final want = expected?.toString();
    if (actual?.toString() != want) {
      throw StateError(
        "Signal '$key' is '$actual', expected '$want'.",
      );
    }
  },
);
