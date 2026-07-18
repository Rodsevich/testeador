import 'dart:async';

import 'package:testeador/src/live/live_persona.dart';

/// Host client that live-configures the **questline runtime** of a running
/// Flutter app (signals, liturgical clock, mission/unlock state) by invoking
/// its `ext.questline.*` service extensions over the VM service.
///
/// It reuses the same [PersonaVmBackend] abstraction as [LivePersonaClient]
/// (no vm_service re-implementation) and the same discovery-with-timeout, so a
/// dev app that has not registered the extensions yet fails with an actionable
/// error instead of hanging.
///
/// The extension contract (fixed, implemented by `QuestlineDevtools`): params
/// are always strings, the response lives in the extension's JSON body.
/// - [dumpStateExt] → `{targets, signals:{key:{value,type}}, clock}`
/// - [setSignalExt] `{key,value,type}` → `{signals}`
/// - [forceClockExt] `{minutes}` | `{iso}` | `{millis}` → `{clock}`
/// - [clearClockExt] → `{clock}`
class QuestlineLiveClient {
  /// Creates a client against the VM service at [wsUri]. [connect] is injected
  /// in tests to avoid needing a real VM.
  QuestlineLiveClient({
    required this.wsUri,
    Future<PersonaVmBackend> Function(String wsUri)? connect,
  }) : _connect = connect ?? VmServicePersonaBackend.connect;

  /// ws:// URI of the running app's VM service / DDS.
  final String wsUri;

  final Future<PersonaVmBackend> Function(String wsUri) _connect;

  /// Dumps the whole questline runtime state.
  static const String dumpStateExt = 'ext.questline.dumpState';

  /// Sets a single signal.
  static const String setSignalExt = 'ext.questline.setSignal';

  /// Pins / forces the liturgical clock.
  static const String forceClockExt = 'ext.questline.forceClock';

  /// Releases a forced clock back to real time.
  static const String clearClockExt = 'ext.questline.clearClock';

  /// Start minute-of-day of each liturgical window, keyed by name.
  ///
  /// Both the accentless and accented spellings of *vísperas* are accepted;
  /// lookups are case-insensitive (see [forceLiturgicalHour]).
  static const Map<String, int> liturgicalHours = <String, int>{
    'vigiliae': 0,
    'laudes': 300,
    'tercia': 480,
    'sexta': 660,
    'nona': 840,
    'visperas': 1020,
    'vísperas': 1020,
    'completas': 1200,
  };

  /// Default seconds to wait for the extension to be registered.
  static const Duration defaultTimeout = Duration(seconds: 15);

  /// Returns the full runtime state: `{targets, signals, clock}`.
  Future<Map<String, dynamic>> dumpState({Duration timeout = defaultTimeout}) =>
      _withExtension(dumpStateExt, timeout, const <String, dynamic>{});

  /// Sets signal [key] to [value].
  ///
  /// [type] is one of `bool|int|double|string|null`; when omitted it is
  /// inferred from the runtime type of [value]. [value] is serialized to a
  /// string as the contract requires.
  Future<Map<String, dynamic>> setSignal(
    String key,
    Object? value, {
    String? type,
    Duration timeout = defaultTimeout,
  }) =>
      _withExtension(setSignalExt, timeout, <String, dynamic>{
        'key': key,
        'value': value?.toString() ?? '',
        'type': type ?? _inferType(value),
      });

  /// Forces the clock to [minutes] past midnight (0..1439).
  Future<Map<String, dynamic>> forceHour(
    int minutes, {
    Duration timeout = defaultTimeout,
  }) {
    if (minutes < 0 || minutes > 1439) {
      throw ArgumentError.value(
        minutes,
        'minutes',
        'Must be 0..1439 (minute of day)',
      );
    }
    return _withExtension(forceClockExt, timeout, <String, dynamic>{
      'minutes': '$minutes',
    });
  }

  /// Forces the clock to the instant described by ISO-8601 [iso].
  Future<Map<String, dynamic>> forceClockIso(
    String iso, {
    Duration timeout = defaultTimeout,
  }) =>
      _withExtension(forceClockExt, timeout, <String, dynamic>{'iso': iso});

  /// Forces the clock to the start of liturgical hour [name]
  /// (see [liturgicalHours]). Throws [ArgumentError] on an unknown name.
  Future<Map<String, dynamic>> forceLiturgicalHour(
    String name, {
    Duration timeout = defaultTimeout,
  }) {
    final minutes = liturgicalHours[name.trim().toLowerCase()];
    if (minutes == null) {
      throw ArgumentError.value(
        name,
        'name',
        'Unknown liturgical hour. Known: ${liturgicalHours.keys.join(', ')}',
      );
    }
    return forceHour(minutes, timeout: timeout);
  }

  /// Releases a forced clock, returning to real time.
  Future<Map<String, dynamic>> clearClock({
    Duration timeout = defaultTimeout,
  }) =>
      _withExtension(clearClockExt, timeout, const <String, dynamic>{});

  static String _inferType(Object? value) {
    if (value == null) return 'null';
    if (value is bool) return 'bool';
    if (value is int) return 'int';
    if (value is double) return 'double';
    return 'string';
  }

  // ponytail: one VM connection per call (mirrors LivePersonaClient). Fine for
  // dev/test cadence; batch onto a persistent backend if it ever gets chatty.
  Future<Map<String, dynamic>> _withExtension(
    String ext,
    Duration timeout,
    Map<String, dynamic> args,
  ) async {
    final backend = await _connect(wsUri);
    try {
      final isolateId = await backend.mainIsolateId();
      await awaitExtension(
        backend,
        isolateId,
        ext,
        timeout,
        notRunningHint: '¿La app dev (con QuestlineDevtools) está corriendo y '
            'conectada a este VM service?',
      );
      return await backend.call(ext, isolateId, args);
    } finally {
      await backend.dispose();
    }
  }
}
