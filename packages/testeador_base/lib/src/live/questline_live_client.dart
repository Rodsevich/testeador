import 'package:dev_mate_client/dev_mate_client.dart';

/// Host client that live-configures a running app's questline runtime and
/// forceable clock: thin shim over [DevMateClient] keeping the historical
/// typed API used by flows, steps and tools.
///
/// Since the dev_mate consolidation the CLOCK is not questline's anymore:
/// `forceHour`/`clearClock` talk to dev_mate's built-in `clock` domain
/// (`ext.dev_mate.clock.*`), and the liturgical-hour names are read from the
/// app's own presets in the catalog (label → minutes) instead of a local
/// hardcoded map — the truth lives app-side.
class QuestlineLiveClient {
  /// Creates a client against the VM service at [wsUri]. `connect` is
  /// injected in tests (`FakeVmBackend`) to avoid a real VM.
  QuestlineLiveClient({
    required this.wsUri,
    Future<VmBackend> Function(String wsUri)? connect,
  }) : _client = DevMateClient(wsUri: wsUri, connect: connect);

  /// ws:// URI of the running app's VM service / DDS.
  final String wsUri;

  final DevMateClient _client;

  /// Dumps the questline runtime state.
  static const String dumpStateExt = 'ext.questline.dumpState';

  /// Sets a single signal.
  static const String setSignalExt = 'ext.questline.setSignal';

  /// Pins the app's forceable clock (dev_mate built-in domain).
  static const String forceClockExt = 'ext.dev_mate.clock.force';

  /// Releases a forced clock back to real time.
  static const String clearClockExt = 'ext.dev_mate.clock.clear';

  /// Default seconds to wait for an extension to be registered.
  static const Duration defaultTimeout = Duration(seconds: 15);

  /// Returns the questline runtime state: `{targets, signals}`.
  Future<Map<String, dynamic>> dumpState({
    Duration timeout = defaultTimeout,
  }) async => (await _client.invoke(
    dumpStateExt,
    const <String, Object?>{},
    timeout: timeout,
  )).body;

  /// Sets signal [key] to [value].
  ///
  /// [type] is one of `bool|int|double|string|null`; when omitted it is
  /// inferred from the runtime type of [value] (host-side sugar — the wire
  /// always carries strings).
  Future<Map<String, dynamic>> setSignal(
    String key,
    Object? value, {
    String? type,
    Duration timeout = defaultTimeout,
  }) async => (await _client.invoke(setSignalExt, <String, Object?>{
    'key': key,
    'value': value?.toString() ?? '',
    'type': type ?? _inferType(value),
  }, timeout: timeout)).body;

  /// Forces the clock to [minutes] past midnight (0..1439).
  Future<Map<String, dynamic>> forceHour(
    int minutes, {
    Duration timeout = defaultTimeout,
  }) async {
    if (minutes < 0 || minutes > 1439) {
      throw ArgumentError.value(
        minutes,
        'minutes',
        'Must be 0..1439 (minute of day)',
      );
    }
    return (await _client.invoke(forceClockExt, <String, Object?>{
      'minutes': minutes,
    }, timeout: timeout)).body;
  }

  /// Forces the clock to the instant described by ISO-8601 [iso].
  Future<Map<String, dynamic>> forceClockIso(
    String iso, {
    Duration timeout = defaultTimeout,
  }) async => (await _client.invoke(forceClockExt, <String, Object?>{
    'iso': iso,
  }, timeout: timeout)).body;

  /// Forces the clock to the start of liturgical hour [name], resolving the
  /// label against the app's clock presets in the dev_mate catalog. Throws
  /// [ArgumentError] on an unknown label.
  Future<Map<String, dynamic>> forceLiturgicalHour(
    String name, {
    Duration timeout = defaultTimeout,
  }) async {
    final presets = await _clockPresets(timeout: timeout);
    final wanted = _fold(name);
    final match = presets.entries
        .where((e) => _fold(e.key) == wanted)
        .map((e) => e.value)
        .firstOrNull;
    if (match == null) {
      throw ArgumentError.value(
        name,
        'name',
        'Unknown liturgical hour. App presets: ${presets.keys.join(', ')}',
      );
    }
    return forceHour(int.parse(match), timeout: timeout);
  }

  /// Releases a forced clock, returning to real time.
  Future<Map<String, dynamic>> clearClock({
    Duration timeout = defaultTimeout,
  }) async => (await _client.invoke(
    clearClockExt,
    const <String, Object?>{},
    timeout: timeout,
  )).body;

  /// label → wire value of the `minutes` presets of the app's clock domain.
  Future<Map<String, String>> _clockPresets({
    required Duration timeout,
  }) async {
    final catalog = await _client.discover(timeout: timeout);
    final domains = (catalog['domains'] as List?) ?? const <Object?>[];
    for (final domain in domains.whereType<Map<String, dynamic>>()) {
      if (domain['name'] != 'clock') continue;
      final actions = (domain['actions'] as List?) ?? const <Object?>[];
      for (final action in actions.whereType<Map<String, dynamic>>()) {
        if (action['name'] != 'force') continue;
        final params = (action['params'] as List?) ?? const <Object?>[];
        for (final param in params.whereType<Map<String, dynamic>>()) {
          if (param['name'] != 'minutes') continue;
          final enums = (param['enumValues'] as List?) ?? const <Object?>[];
          return <String, String>{
            for (final e in enums.whereType<Map<String, dynamic>>())
              '${e['label']}': '${e['value']}',
          };
        }
      }
    }
    return const <String, String>{};
  }

  /// Case/accent-insensitive label folding (vísperas == visperas).
  static String _fold(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  static String _inferType(Object? value) {
    if (value == null) return 'null';
    if (value is bool) return 'bool';
    if (value is int) return 'int';
    if (value is double) return 'double';
    return 'string';
  }
}
