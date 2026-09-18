import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:testeador_base/src/mirador/capture.dart';
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
    this.take,
    this.captureScenario = 'en vivo',
    this.captureActor = 'dev',
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

  /// Cómo sacar una captura cuando el panel pide `POST /capture`. Sin esto la
  /// ruta responde 501: no todos los contextos tienen un device a mano.
  final ScreenshotTaker? take;

  /// Escenario y actor con que se registran las capturas en vivo del panel.
  final String captureScenario;

  /// Actor de las capturas en vivo.
  final String captureActor;

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
        // El visor embebido en DevTools corre en OTRO origen (su propio
        // puerto), así que sin esto el navegador le bloquea cada fetch. El
        // server ya escucha sólo en loopback, así que abrir el origen no
        // amplía a quién puede llegarle.
        req.response.headers
          ..set('Access-Control-Allow-Origin', '*')
          ..set('Access-Control-Allow-Headers', 'content-type')
          ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        if (req.method == 'OPTIONS') {
          req.response.statusCode = HttpStatus.ok;
          await req.response.close();
          continue;
        }
        if (req.method == 'POST' && path == '/capture') {
          await _capture(req);
          continue;
        }
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

  /// Saca una captura en vivo y responde con el ítem recién creado, para que
  /// el panel pueda mostrarla sin recargar la cola entera.
  Future<void> _capture(HttpRequest req) async {
    final taker = take;
    if (taker == null) {
      req.response
        ..statusCode = HttpStatus.notImplemented
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'ok': false,
            'error':
                'este panel se levantó sin device: relanzá `mirador review` '
                'con --serial para poder capturar desde acá',
          }),
        );
      await req.response.close();
      return;
    }
    final body = await utf8.decoder.bind(req).join();
    final args = body.isEmpty
        ? const <String, Object?>{}
        : jsonDecode(body) as Map<String, Object?>;
    try {
      final result = await captureLive(
        take: taker,
        baseDir: baseDir,
        scenario: (args['scenario'] as String?) ?? captureScenario,
        actor: (args['actor'] as String?) ?? captureActor,
        slug: (args['slug'] as String?) ?? 'captura',
        intent: args['intent'] as String?,
      );
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'ok': true,
            'scenario': result.scenario,
            'actor': result.actor,
            'slug': result.slug,
            'capture': result.capture,
            'marks': result.marks,
            'ratio': result.ratio,
            'isNew': result.isNew,
          }),
        );
    } on Object catch (e) {
      req.response
        ..statusCode = HttpStatus.internalServerError
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'ok': false, 'error': e.toString()}));
    }
    await req.response.close();
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
