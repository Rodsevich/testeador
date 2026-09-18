import 'dart:convert';
import 'dart:io';

import 'package:dev_mate_client/dev_mate_client.dart';

/// Resuelve el `ws://` del VM service de la app que corre en dev, leyendo el
/// mismo archivo que ya escribe `flutter run --vmservice-out-file` (y que
/// stabilitas usa para el `attach` de VS Code, `vmServiceInfoFile`): el
/// `.json` con `vm-service-info` en el nombre modificado más recientemente
/// dentro de [infoDir], forma `{"uri": "http://host:port/token/"}`.
///
/// Nada nuevo que descubrir: es la misma fuente que ya alimenta el `attach`
/// del editor, solo que la lee un script en vez de VS Code.
Future<String> resolveVmUri(String infoDir) async {
  final dir = Directory(infoDir);
  final candidates = await dir
      .list()
      .where((e) => e is File && e.path.contains('vm-service-info'))
      .cast<File>()
      .toList();
  if (candidates.isEmpty) {
    throw StateError(
      'ningún *vm-service-info*.json en $infoDir — '
      '¿la app está corriendo en dev?',
    );
  }
  candidates.sort(
    (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
  );
  final decoded =
      jsonDecode(await candidates.first.readAsString())
          as Map<String, Object?>;
  final httpUri = decoded['uri']! as String;
  final parsed = Uri.parse(httpUri);
  return parsed.replace(scheme: 'ws', path: '${parsed.path}ws').toString();
}

/// Invoca `ext.dev_mate.reporter.capture` en la app corriendo en dev, con
/// autodiscovery del VM service vía [resolveVmUri]. Devuelve la metadata tal
/// cual la arma el dominio `reporter` (`route`, `lastError`, `blocStates`,
/// `widgetTree`, `message`).
Future<Map<String, dynamic>> captureReport({
  required String infoDir,
  String message = '',
}) async {
  final wsUri = await resolveVmUri(infoDir);
  final client = DevMateClient(wsUri: wsUri);
  final result = await client.invoke(
    'ext.dev_mate.reporter.capture',
    <String, Object?>{'message': message},
  );
  return result.body;
}
