import 'dart:async';

import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Backend mínimo sobre el VM service de una app corriendo, con solo lo que el
/// [LivePersonaClient] necesita. Se extrae a una interfaz para poder testear el
/// cliente (discovery/timeout/serialización) con un fake, sin un VM real.
abstract interface class PersonaVmBackend {
  /// Id del isolate principal (donde la app registra `ext.stabilitas.*`).
  Future<String> mainIsolateId();

  /// Nombres de las service extensions registradas en [isolateId].
  Future<Set<String>> extensionRPCs(String isolateId);

  /// Invoca [method] en [isolateId] con [args]; devuelve el JSON de la
  /// respuesta.
  Future<Map<String, dynamic>> call(
    String method,
    String isolateId,
    Map<String, dynamic> args,
  );

  /// Cierra la conexión.
  Future<void> dispose();
}

/// [PersonaVmBackend] real sobre `package:vm_service`.
class VmServicePersonaBackend implements PersonaVmBackend {
  /// Envuelve un [VmService] ya conectado.
  VmServicePersonaBackend(this._service);

  /// Conecta al VM service en [wsUri] (ej. `ws://127.0.0.1:PORT/ws`).
  static Future<VmServicePersonaBackend> connect(String wsUri) async {
    final service = await vmServiceConnectUri(wsUri);
    return VmServicePersonaBackend(service);
  }

  final VmService _service;

  @override
  Future<String> mainIsolateId() async {
    final vm = await _service.getVM();
    final isolates = vm.isolates;
    if (isolates == null || isolates.isEmpty) {
      throw StateError('No hay isolates en el VM service.');
    }
    return isolates.first.id!;
  }

  @override
  Future<Set<String>> extensionRPCs(String isolateId) async {
    final isolate = await _service.getIsolate(isolateId);
    return (isolate.extensionRPCs ?? const <String>[]).toSet();
  }

  @override
  Future<Map<String, dynamic>> call(
    String method,
    String isolateId,
    Map<String, dynamic> args,
  ) async {
    final res = await _service.callServiceExtension(
      method,
      isolateId: isolateId,
      args: args,
    );
    return res.json ?? <String, dynamic>{};
  }

  @override
  Future<void> dispose() => _service.dispose();
}

/// Polls [backend] until the service extension [ext] is registered on
/// [isolateId], returning as soon as it is. Throws a [TimeoutException]
/// carrying [notRunningHint] if it never appears within [timeout].
///
/// Shared discovery logic: both [LivePersonaClient] and the questline client
/// must wait for the running app to register its `ext.*` extensions before
/// invoking them, instead of hanging indefinitely (GAP-4).
Future<void> awaitExtension(
  PersonaVmBackend backend,
  String isolateId,
  String ext,
  Duration timeout, {
  String notRunningHint = 'Is the target app running and connected to this '
      'VM service?',
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final rpcs = await backend.extensionRPCs(isolateId);
    if (rpcs.contains(ext)) return;
    if (!DateTime.now().isBefore(deadline)) {
      throw TimeoutException(
        "'$ext' no está registrada tras ${timeout.inSeconds}s. $notRunningHint",
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}

/// Cliente host de la siembra en vivo: se conecta al VM service de la app
/// dev de Stabilitas e invoca sus service extensions `ext.stabilitas.*`.
///
/// Hace *discovery* de la extensión con un timeout (la app puede no haber
/// arrancado aún, o no ser el flavor dev), devolviendo un error accionable en
/// vez de colgarse (GAP-4).
class LivePersonaClient {
  /// Crea un cliente contra el VM service en [wsUri]. [connect] se inyecta en
  /// tests para no requerir un VM real.
  LivePersonaClient({
    required this.wsUri,
    Future<PersonaVmBackend> Function(String wsUri)? connect,
  }) : _connect = connect ?? VmServicePersonaBackend.connect;

  /// ws:// del VM service / DDS de la app corriendo.
  final String wsUri;

  final Future<PersonaVmBackend> Function(String wsUri) _connect;

  /// Extension que siembra/cambia la persona activa.
  static const String setPersonaExt = 'ext.stabilitas.setPersona';

  /// Extension que lista las personas disponibles.
  static const String listPersonasExt = 'ext.stabilitas.listPersonas';

  /// Extension que informa la persona activa.
  static const String getActivePersonaExt = 'ext.stabilitas.getActivePersona';

  /// Siembra [persona] (o sale del modo fixture si es `null`/vacío).
  Future<Map<String, dynamic>> setPersona(
    String? persona, {
    Duration timeout = const Duration(seconds: 15),
  }) => _withExtension(setPersonaExt, timeout, <String, dynamic>{
    if (persona != null && persona.isNotEmpty) 'persona': persona,
  });

  /// Lista las personas disponibles que expone la app.
  Future<Map<String, dynamic>> listPersonas({
    Duration timeout = const Duration(seconds: 15),
  }) => _withExtension(listPersonasExt, timeout, const <String, dynamic>{});

  /// La persona activa actualmente en la app.
  Future<Map<String, dynamic>> activePersona({
    Duration timeout = const Duration(seconds: 15),
  }) => _withExtension(getActivePersonaExt, timeout, const <String, dynamic>{});

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
        notRunningHint: '¿La app dev (flavor dev) está corriendo y conectada '
            'a este VM service?',
      );
      return await backend.call(ext, isolateId, args);
    } finally {
      await backend.dispose();
    }
  }
}
