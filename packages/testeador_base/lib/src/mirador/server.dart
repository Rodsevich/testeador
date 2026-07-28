import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:testeador_base/src/mirador/review.dart';
import 'package:testeador_base/src/mirador/ui.dart';

/// El panel de supervisión: sirve la cola de revisión y espera el veredicto.
///
/// Con [once] en `true` —el modo del loop de trabajo— el server se cierra en
/// cuanto recibe el POST del veredicto y [serve] completa. Eso convierte la
/// espera en **un solo evento**: quien lo lanzó en background recibe su
/// notificación de salida y sigue, sin hacer polling.
final class MiradorServer {
  /// Configura el panel sobre [baseDir].
  MiradorServer({
    required this.baseDir,
    this.port = 4771,
    this.once = true,
    this.address,
  });

  /// Raíz de la evidencia (`test_evidence/`). También es el **sandbox**: no se
  /// sirve ningún archivo de afuera.
  final String baseDir;

  /// Puerto a escuchar; 0 deja que el SO elija.
  final int port;

  /// Cerrar en cuanto llegue el veredicto.
  final bool once;

  /// Por defecto solo loopback: el panel expone capturas del proyecto.
  final InternetAddress? address;

  HttpServer? _server;

  /// Puerto real (útil cuando se pide 0).
  int get boundPort => _server?.port ?? port;

  /// Levanta el server y resuelve con el veredicto cuando llega, o con `null`
  /// si se cerró antes (por [close]).
  Future<ReviewOutcome?> serve({
    Map<String, Proposal> proposals = const {},
    bool includeUnchanged = false,
  }) async {
    final server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    _server = server;

    final root = p.normalize(Directory(baseDir).absolute.path);
    ReviewOutcome? outcome;

    await for (final req in server) {
      try {
        final path = req.uri.path;
        if (req.method == 'GET' && (path == '/' || path == '/index.html')) {
          req.response
            ..headers.contentType = ContentType.html
            ..write(miradorHtml());
          await req.response.close();
        } else if (req.method == 'GET' && path == '/queue') {
          final items = loadQueue(
            baseDir: baseDir,
            proposals: proposals,
            includeUnchanged: includeUnchanged,
          );
          req.response
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'baseDir': root,
                'brushes': brushCatalogJson(),
                'items': [for (final i in items) i.toJson()],
              }),
            );
          await req.response.close();
        } else if (req.method == 'GET' && path == '/shot') {
          await _serveShot(req, root);
        } else if (req.method == 'POST' && path == '/verdict') {
          final body = await utf8.decoder.bind(req).join();
          outcome = ReviewOutcome.fromJson(
            jsonDecode(body) as Map<String, Object?>,
          );
          appendVerdicts(
            baseDir: baseDir,
            decisions: outcome.decisions,
            judgedAt: DateTime.now().toUtc().toIso8601String(),
          );
          req.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'ok': true,
                'decisions': outcome.decisions.length,
              }),
            );
          await req.response.close();
          if (once) break;
        } else {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        }
      } on Object catch (e) {
        // Un request roto no debe tumbar la revisión en curso.
        try {
          req.response
            ..statusCode = HttpStatus.internalServerError
            ..write('$e');
          await req.response.close();
        } on Object {
          // La conexión ya se fue.
        }
      }
    }

    await close();
    return outcome;
  }

  /// Sirve un PNG **solo si vive dentro de [baseDir]**. La ruta llega del
  /// cliente, así que se normaliza y se compara contra la raíz antes de abrir
  /// nada: sin esto, un `?p=../../../etc/passwd` leería fuera del proyecto.
  Future<void> _serveShot(HttpRequest req, String root) async {
    final raw = req.uri.queryParameters['p'];
    if (raw == null || raw.isEmpty) {
      req.response.statusCode = HttpStatus.badRequest;
      await req.response.close();
      return;
    }
    final resolved = p.normalize(
      p.isAbsolute(raw) ? raw : p.join(root, raw),
    );
    final inside = resolved == root || p.isWithin(root, resolved);
    final file = File(resolved);
    if (!inside || !file.existsSync()) {
      req.response.statusCode = HttpStatus.forbidden;
      await req.response.close();
      return;
    }
    req.response.headers.contentType = ContentType('image', 'png');
    // Las capturas se reescriben en cada corrida: nunca cachear.
    req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    await req.response.addStream(file.openRead());
    await req.response.close();
  }

  /// Cierra el server si está abierto.
  Future<void> close() async {
    final s = _server;
    _server = null;
    if (s != null) await s.close(force: true);
  }
}
