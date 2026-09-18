import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:testeador_base/evidence.dart';
import 'package:testeador_base/mirador.dart';

void main() {
  late Directory tmp;
  late String base;
  late MiradorServer server;
  late HttpClient client;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mirador_server');
    base = p.join(tmp.path, 'test_evidence');
    final runDir = scenarioRunDir(baseDir: base, scenario: 'flujo');
    Directory(runDir).createSync(recursive: true);
    File(p.join(runDir, 'shot.png')).writeAsBytesSync(
      img.encodePng(img.Image(width: 4, height: 4)),
    );
    File(p.join(runDir, 'actor.manifest.json')).writeAsStringSync(
      jsonEncode({
        'schemaVersion': 1,
        'scenario': 'flujo',
        'actor': 'actor',
        'steps': [
          {
            'order': 1,
            'slug': 'pantalla',
            'description': 'pantalla',
            'status': 'ok',
            'intent': 'se ve entera',
            'capture': 'shot.png',
            'baseline': '../../baseline/flujo/actor-pantalla.png',
            'diff': {
              'ratio': 0.02,
              'marks': 2,
              'dimensionMismatch': false,
            },
          },
        ],
      }),
    );
    // Puerto 0: que el SO elija, así los tests no chocan entre sí.
    server = MiradorServer(baseDir: base, port: 0);
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await server.close();
    tmp.deleteSync(recursive: true);
  });

  Future<HttpClientResponse> get(String path) async {
    final req = await client.getUrl(
      Uri.parse('http://127.0.0.1:${server.boundPort}$path'),
    );
    return req.close();
  }

  test(
    'sirve la página, la cola y el PNG; y cierra al recibir el veredicto',
    () async {
      final pending = server.serve();
      // El bind ya ocurrió cuando serve() devolvió el control al event loop.
      await Future<void>.delayed(const Duration(milliseconds: 60));

      final page = await get('/');
      expect(page.statusCode, 200);
      expect(await page.transform(utf8.decoder).join(), contains('mirador'));

      final queue = await get('/queue');
      final body =
          jsonDecode(await queue.transform(utf8.decoder).join())
              as Map<String, Object?>;
      expect(body['items']! as List, hasLength(1));
      expect(
        body['brushes']! as List,
        hasLength(kBrushes.length),
        reason: 'la UI lee el catálogo del server, no lo repite',
      );

      final shotPath = p.join(
        scenarioRunDir(baseDir: base, scenario: 'flujo'),
        'shot.png',
      );
      final shot = await get('/shot?p=${Uri.encodeQueryComponent(shotPath)}');
      expect(shot.statusCode, 200);
      expect(shot.headers.contentType.toString(), 'image/png');

      final post = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.boundPort}/verdict'),
      );
      post.headers.contentType = ContentType.json;
      post.write(
        jsonEncode({
          'decisions': [
            {
              'scenario': 'flujo',
              'actor': 'actor',
              'slug': 'pantalla',
              'verdict': 'fix_code',
              'rationale': 'modificar: torcido',
              'judgedBy': 'human',
              'capture': 'shot.png',
              'marks': [
                {
                  'brush': 'modificar',
                  'rect': [1, 2, 3, 4],
                  'note': 'acá',
                },
              ],
            },
          ],
          'roundNote': 'la ronda entera',
        }),
      );
      final posted = await post.close();
      expect(posted.statusCode, 200);

      final outcome = await pending;
      expect(outcome, isNotNull);
      expect(outcome!.decisions, hasLength(1));
      expect(outcome.decisions.single.verdict, Verdict.fixCode);
      expect(outcome.decisions.single.marks.single.brushId, 'modificar');
      expect(outcome.roundNote, 'la ronda entera');

      // Y quedó el rastro auditable.
      final verdicts = File(
        p.join(
          scenarioBaselineDir(baseDir: base, scenario: 'flujo'),
          'verdicts.json',
        ),
      );
      expect(verdicts.existsSync(), isTrue);
      expect(verdicts.readAsStringSync(), contains('"judgedBy": "human"'));
    },
  );

  test('/shot NO sirve nada de afuera del baseDir', () async {
    final pending = server.serve();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    // Un secreto fuera del sandbox, alcanzable por travesía de directorios.
    final outside = File(p.join(tmp.path, 'secreto.png'))
      ..writeAsBytesSync(img.encodePng(img.Image(width: 2, height: 2)));

    final byAbsolute = await get(
      '/shot?p=${Uri.encodeQueryComponent(outside.path)}',
    );
    expect(byAbsolute.statusCode, HttpStatus.forbidden);

    final byTraversal = await get(
      '/shot?p=${Uri.encodeQueryComponent('../secreto.png')}',
    );
    expect(byTraversal.statusCode, HttpStatus.forbidden);

    final missing = await get('/shot?p=no-existe.png');
    expect(missing.statusCode, HttpStatus.forbidden);

    final noParam = await get('/shot');
    expect(noParam.statusCode, HttpStatus.badRequest);

    await server.close();
    await pending;
  });

  test('responde CORS y contesta el preflight: el visor de DevTools corre en '
      'otro origen', () async {
    final pending = server.serve();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final res = await get('/queue');
    expect(res.headers.value('access-control-allow-origin'), '*');

    final req = await client.openUrl(
      'OPTIONS',
      Uri.parse('http://127.0.0.1:${server.boundPort}/verdict'),
    );
    final pre = await req.close();
    expect(pre.statusCode, HttpStatus.ok);
    expect(pre.headers.value('access-control-allow-methods'), contains('POST'));

    await server.close();
    await pending;
  });

  test('POST /capture sin device responde 501 con la salida', () async {
    final pending = server.serve();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final req = await client.postUrl(
      Uri.parse('http://127.0.0.1:${server.boundPort}/capture'),
    );
    final res = await req.close();
    expect(res.statusCode, HttpStatus.notImplemented);
    expect(
      await res.transform(utf8.decoder).join(),
      contains('--serial'),
      reason: 'el error tiene que decir cómo habilitarlo',
    );

    await server.close();
    await pending;
  });

  test('POST /capture con device captura y devuelve el ítem', () async {
    final conDevice = MiradorServer(
      baseDir: base,
      port: 0,
      take: (out) async {
        out.parent.createSync(recursive: true);
        return out
          ..writeAsBytesSync(img.encodePng(img.Image(width: 8, height: 8)));
      },
    );
    final pending = conDevice.serve();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final req = await client.postUrl(
      Uri.parse('http://127.0.0.1:${conDevice.boundPort}/capture'),
    );
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'slug': 'hodie', 'intent': 'se ve el día'}));
    final res = await req.close();
    expect(res.statusCode, HttpStatus.ok);

    final body =
        jsonDecode(await res.transform(utf8.decoder).join())
            as Map<String, Object?>;
    expect(body['ok'], isTrue);
    expect(body['slug'], 'hodie');
    expect(body['isNew'], isTrue);
    expect(File(body['capture']! as String).existsSync(), isTrue);

    await conDevice.close();
    await pending;
  });

  test('una ruta desconocida es 404 y no tumba el server', () async {
    final pending = server.serve();
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect((await get('/nope')).statusCode, HttpStatus.notFound);
    expect((await get('/queue')).statusCode, HttpStatus.ok);

    await server.close();
    await pending;
  });
}
