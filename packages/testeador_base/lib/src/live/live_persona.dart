import 'package:dev_mate_client/dev_mate_client.dart';

/// Host client of the live persona seeding: thin shim over [DevMateClient]
/// that keeps the historical typed API (`setPersona`/`listPersonas`/
/// `activePersona`) used by flows and tools.
///
/// The VM transport (backend, discovery-with-timeout) LIVES IN dev_mate now
/// (`VmBackend`/`awaitExtension` in `package:dev_mate_client`); testeador
/// only keeps its domain vocabulary. Wire unchanged: `ext.stabilitas.*`.
class LivePersonaClient {
  /// Creates a client against the VM service at [wsUri]. `connect` is
  /// injected in tests (`FakeVmBackend`) to avoid a real VM.
  LivePersonaClient({
    required this.wsUri,
    Future<VmBackend> Function(String wsUri)? connect,
  }) : _client = DevMateClient(wsUri: wsUri, connect: connect);

  /// ws:// URI of the running app's VM service / DDS.
  final String wsUri;

  final DevMateClient _client;

  /// Extension that seeds/changes the active persona.
  static const String setPersonaExt = 'ext.stabilitas.setPersona';

  /// Extension that lists the available personas.
  static const String listPersonasExt = 'ext.stabilitas.listPersonas';

  /// Extension that reports the active persona.
  static const String getActivePersonaExt = 'ext.stabilitas.getActivePersona';

  /// Seeds [persona] (or exits fixture mode when null/empty).
  Future<Map<String, dynamic>> setPersona(
    String? persona, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final res = await _client.invoke(setPersonaExt, <String, Object?>{
      if (persona != null && persona.isNotEmpty) 'persona': persona,
    }, timeout: timeout);
    return res.body;
  }

  /// Lists the personas the app exposes.
  Future<Map<String, dynamic>> listPersonas({
    Duration timeout = const Duration(seconds: 15),
  }) async => (await _client.invoke(
    listPersonasExt,
    const <String, Object?>{},
    timeout: timeout,
  )).body;

  /// The currently active persona.
  Future<Map<String, dynamic>> activePersona({
    Duration timeout = const Duration(seconds: 15),
  }) async => (await _client.invoke(
    getActivePersonaExt,
    const <String, Object?>{},
    timeout: timeout,
  )).body;
}
