import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Captures a screenshot of [url] by driving headless Chrome over the DevTools
/// Protocol (CDP) and **waiting for a readiness signal** before the shot.
///
/// Why not `chrome --headless --screenshot <url>`? That one-shot mode captures
/// as soon as the load event fires while fast-forwarding virtual time, so a
/// single-page app (Flutter web in particular) is photographed mid-bootstrap —
/// stuck on its splash. CDP keeps a real event loop running: we navigate, poll
/// [readyExpression] until it returns truthy (or [readyTimeout] elapses), let
/// the frame settle, then capture.
///
/// Pure Dart — `HttpClient` for target discovery + a `WebSocket` CDP client.
/// No Node, no extra deps. The Chrome process is always killed and the temp
/// profile removed, even on failure, so a wedged browser can't leak.
Future<void> captureWebPage({
  required String chromePath,
  required String url,
  required File out,
  int width = 1280,
  int height = 900,
  String readyExpression = "document.querySelector('flutter-view') != null",
  Duration readyTimeout = const Duration(seconds: 30),
  Duration settle = const Duration(milliseconds: 1500),
  Duration launchTimeout = const Duration(seconds: 20),
  Duration pollInterval = const Duration(milliseconds: 250),
  Map<String, String> cookies = const {},
  String? initScript,
}) async {
  final profile = await Directory.systemTemp.createTemp('eb-webdevice-');
  Process? proc;
  WebSocket? ws;
  try {
    proc = await Process.start(chromePath, [
      '--headless=new',
      '--disable-gpu',
      '--hide-scrollbars',
      '--force-device-scale-factor=1',
      '--window-size=$width,$height',
      '--remote-debugging-port=0',
      '--user-data-dir=${profile.path}',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-extensions',
      '--disable-background-networking',
      'about:blank',
    ]);
    unawaited(proc.stdout.drain<void>());
    unawaited(proc.stderr.drain<void>());

    final port = await _readDevtoolsPort(profile, launchTimeout);
    final wsUrl = await _pageWebSocketUrl(port, launchTimeout);
    ws = await WebSocket.connect(wsUrl).timeout(launchTimeout);
    final cdp = _Cdp(ws);

    await cdp.send('Page.enable');
    await cdp.send('Runtime.enable');
    await cdp.send('Network.enable');

    final origin = Uri.parse(url);
    for (final entry in cookies.entries) {
      await cdp.send('Network.setCookie', {
        'name': entry.key,
        'value': entry.value,
        'domain': origin.host,
        'path': '/',
      });
    }
    if (initScript != null) {
      await cdp.send('Page.addScriptToEvaluateOnNewDocument', {
        'source': initScript,
      });
    }

    await cdp.send('Page.navigate', {'url': url});

    final deadline = DateTime.now().add(readyTimeout);
    var ready = false;
    while (DateTime.now().isBefore(deadline)) {
      try {
        final res = await cdp.send('Runtime.evaluate', {
          'expression': '!!($readyExpression)',
          'returnByValue': true,
        });
        if ((res['result'] as Map?)?['value'] == true) {
          ready = true;
          break;
        }
      } on Object {
        // Evaluate can transiently fail mid-navigation — treat as not-ready.
      }
      await Future<void>.delayed(pollInterval);
    }
    if (!ready) {
      stderr.writeln(
        '  [web_capture] readiness "$readyExpression" not met within '
        '${readyTimeout.inSeconds}s for $url — capturing current state.',
      );
    }
    await Future<void>.delayed(settle);

    final shot = await cdp.send('Page.captureScreenshot', {'format': 'png'});
    final data = shot['data'] as String?;
    if (data == null) {
      throw StateError('CDP Page.captureScreenshot returned no data for $url');
    }
    await out.parent.create(recursive: true);
    await out.writeAsBytes(base64.decode(data));
  } finally {
    await ws?.close();
    proc?.kill(ProcessSignal.sigkill);
    try {
      await profile.delete(recursive: true);
    } on Object {
      // best-effort
    }
  }
}

/// Polls `<profile>/DevToolsActivePort` (written by Chrome when launched with
/// `--remote-debugging-port=0`) and returns the chosen port.
Future<int> _readDevtoolsPort(Directory profile, Duration timeout) async {
  final file = File('${profile.path}/DevToolsActivePort');
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (file.existsSync()) {
      final firstLine =
          file.readAsLinesSync().firstWhere((l) => l.trim().isNotEmpty,
              orElse: () => '');
      final port = int.tryParse(firstLine.trim());
      if (port != null) return port;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  throw TimeoutException(
    'Chrome did not expose a DevTools port within ${timeout.inSeconds}s.',
  );
}

/// Discovers the WebSocket debugger URL of a page target via the JSON endpoint.
Future<String> _pageWebSocketUrl(int port, Duration timeout) async {
  final client = HttpClient();
  try {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final req =
            await client.getUrl(Uri.parse('http://127.0.0.1:$port/json'));
        final resp = await req.close();
        final body = await resp.transform(utf8.decoder).join();
        final targets = (jsonDecode(body) as List).cast<Map<String, dynamic>>();
        final page = targets.firstWhere(
          (t) => t['type'] == 'page' && t['webSocketDebuggerUrl'] != null,
          orElse: () => const {},
        );
        final wsUrl = page['webSocketDebuggerUrl'] as String?;
        if (wsUrl != null) return wsUrl;
      } on Object {
        // Endpoint not up yet — retry.
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    throw TimeoutException(
      'No CDP page target on :$port within ${timeout.inSeconds}s.',
    );
  } finally {
    client.close(force: true);
  }
}

/// Minimal CDP client: correlates `{id}` responses, ignores events.
class _Cdp {
  _Cdp(this._ws) {
    _ws.listen((dynamic data) {
      final msg = jsonDecode(data as String) as Map<String, dynamic>;
      final id = msg['id'];
      if (id is int) {
        final completer = _pending.remove(id);
        if (completer == null) return;
        if (msg['error'] != null) {
          completer.completeError(StateError('CDP error: ${msg['error']}'));
        } else {
          completer.complete(
            (msg['result'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
        }
      }
    }, onError: (Object _) {}, cancelOnError: false);
  }

  final WebSocket _ws;
  int _nextId = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  Future<Map<String, dynamic>> send(
    String method, [
    Map<String, dynamic>? params,
  ]) {
    final id = ++_nextId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _ws.add(jsonEncode({
      'id': id,
      'method': method,
      'params': ?params,
    }));
    return completer.future.timeout(const Duration(seconds: 30));
  }
}
