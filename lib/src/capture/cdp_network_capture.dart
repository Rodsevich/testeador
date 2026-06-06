import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:testeador/src/capture/captured_exchange.dart';
import 'package:testeador/src/capture/traffic_capture.dart';

/// Pure, transport-free aggregator of Chrome DevTools Protocol Network events
/// into [CapturedExchange]s.
///
/// The live [CdpNetworkCapture] feeds it raw CDP event params; this class
/// holds the (entirely synchronous) correlation logic so it can be unit-tested
/// with event fixtures — no Chrome, no mocks. Only `XHR`/`Fetch` requests
/// become exchanges (those are the app's backend API calls); document, script,
/// image and font requests are ignored, and `EventSource`/`WebSocket` channels
/// are recorded as out-of-scope observations instead of being silently dropped.
class CdpExchangeAssembler {
  final Map<String, _Pending> _inflight = {};
  final List<CapturedExchange> _done = [];
  final List<String> _nonHttp = [];

  static const _apiTypes = {'XHR', 'Fetch'};

  /// Handles a `Network.requestWillBeSent` event.
  void onRequestWillBeSent(Map<String, dynamic> params) {
    final requestId = params['requestId'] as String?;
    final request = (params['request'] as Map?)?.cast<String, dynamic>();
    if (requestId == null || request == null) return;

    final type = params['type'] as String?;
    if (type == 'EventSource') {
      _nonHttp.add('SSE (EventSource): ${request['url']}');
      return;
    }
    if (type != null && !_apiTypes.contains(type)) return;

    _inflight[requestId] = _Pending(
      method: (request['method'] as String?) ?? 'GET',
      url: Uri.parse((request['url'] as String?) ?? ''),
      requestHeaders: _headers(request['headers']),
      requestBody: request['postData'] as String?,
    );
  }

  /// Handles a `Network.responseReceived` event.
  void onResponseReceived(Map<String, dynamic> params) {
    final requestId = params['requestId'] as String?;
    final response = (params['response'] as Map?)?.cast<String, dynamic>();
    final pending = _inflight[requestId];
    if (pending == null || response == null) return;
    pending
      ..status = response['status'] as int?
      ..responseHeaders = _headers(response['headers']);
  }

  /// Handles a `Network.webSocketCreated` event (recorded, not captured).
  void onWebSocketCreated(Map<String, dynamic> params) {
    _nonHttp.add('WebSocket: ${params['url']}');
  }

  /// Completes the exchange for [requestId] once its body is available (or
  /// known to be unavailable). [partial] marks a missing/undecodable body.
  void finalize(
    String requestId, {
    String? responseBody,
    bool partial = false,
  }) {
    final pending = _inflight.remove(requestId);
    if (pending == null) return;
    _done.add(
      CapturedExchange(
        method: pending.method,
        url: pending.url,
        requestHeaders: pending.requestHeaders,
        responseHeaders: pending.responseHeaders,
        requestBody: pending.requestBody,
        status: pending.status,
        responseBody: responseBody,
        partial: partial || pending.status == null,
      ),
    );
  }

  /// Marks the request as failed/aborted; it is still recorded (partial) so the
  /// endpoint is never silently dropped from the gap report.
  void markFailed(String requestId) => finalize(requestId, partial: true);

  /// Captured exchanges in a deterministic order (by endpoint identity, not
  /// arrival), so regenerated output is stable across runs.
  List<CapturedExchange> exchanges() {
    final out = [..._done]
      ..sort(
        (a, b) => a.endpointId().toString().compareTo(
          b.endpointId().toString(),
        ),
      );
    return out;
  }

  /// Non-HTTP channels observed (WebSocket/SSE): out of scope for generation,
  /// surfaced so callers know that surface is uncovered.
  List<String> nonHttpChannels() => List.unmodifiable(_nonHttp);

  Map<String, String> _headers(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries) e.key.toString().toLowerCase(): '${e.value}',
    };
  }
}

class _Pending {
  _Pending({
    required this.method,
    required this.url,
    required this.requestHeaders,
    this.requestBody,
  });
  final String method;
  final Uri url;
  final Map<String, String> requestHeaders;
  final String? requestBody;
  int? status;
  Map<String, String> responseHeaders = const {};
}

/// [TrafficCapture] backend for Flutter **web**: attaches to a running Chrome
/// over the DevTools Protocol and records `XHR`/`Fetch` traffic via the
/// Network domain.
///
/// Attach mode — point it at an existing Chrome's `--remote-debugging-port`
/// (the same instance an AI/automation may already be driving). Response
/// bodies are fetched on `Network.loadingFinished`; a body that CDP can no
/// longer serve ("No data found") yields a partial exchange instead of an
/// error. Buffer sizes are fixed at sensible defaults.
///
/// The wire transport cannot be unit-tested without a real browser; its
/// correlation logic lives in [CdpExchangeAssembler], which is. End-to-end
/// coverage is exercised against a served Flutter web example.
class CdpNetworkCapture implements TrafficCapture {
  /// Attaches to the Chrome listening on [debugPort]. [onWarning] receives
  /// capture-blind and out-of-scope diagnostics (defaults to stderr).
  CdpNetworkCapture({
    required int debugPort,
    void Function(String message)? onWarning,
  }) : _debugPort = debugPort,
       _onWarning = onWarning ?? stderr.writeln;

  final int _debugPort;
  final void Function(String message) _onWarning;
  final CdpExchangeAssembler _assembler = CdpExchangeAssembler();
  final List<Future<void>> _pendingBodies = [];

  // Fixed buffers (~10 MB total, 5 MB per resource) — no caller knob needed.
  static const int _maxTotalBuffer = 10 * 1024 * 1024;
  static const int _maxResourceBuffer = 5 * 1024 * 1024;

  WebSocket? _ws;
  _CdpClient? _cdp;

  @override
  Future<void> open() async {
    final wsUrl = await _pageWebSocketUrl(_debugPort);
    final ws = await WebSocket.connect(wsUrl);
    _ws = ws;
    _cdp = _CdpClient(ws, onEvent: _onEvent);
    await _cdp!.send('Network.enable', {
      'maxTotalBufferSize': _maxTotalBuffer,
      'maxResourceBufferSize': _maxResourceBuffer,
    });
  }

  void _onEvent(String method, Map<String, dynamic> params) {
    switch (method) {
      case 'Network.requestWillBeSent':
        _assembler.onRequestWillBeSent(params);
      case 'Network.responseReceived':
        _assembler.onResponseReceived(params);
      case 'Network.webSocketCreated':
        _assembler.onWebSocketCreated(params);
      case 'Network.loadingFinished':
        final requestId = params['requestId'] as String?;
        if (requestId != null) _pendingBodies.add(_fetchBody(requestId));
      case 'Network.loadingFailed':
        final requestId = params['requestId'] as String?;
        if (requestId != null) _assembler.markFailed(requestId);
    }
  }

  Future<void> _fetchBody(String requestId) async {
    try {
      final res = await _cdp!.send('Network.getResponseBody', {
        'requestId': requestId,
      });
      final base64Encoded = res['base64Encoded'] == true;
      // Binary bodies aren't useful as a text contract; keep them out but
      // still record the exchange (we have status + headers).
      _assembler.finalize(
        requestId,
        responseBody: base64Encoded ? null : res['body'] as String?,
      );
    } on Object {
      // "No data found for resource" / evicted / streamed — record as partial.
      _assembler.finalize(requestId, partial: true);
    }
  }

  @override
  Future<List<CapturedExchange>> takeExchanges() async {
    await Future.wait(_pendingBodies);
    final exchanges = _assembler.exchanges();
    if (exchanges.isEmpty) {
      _onWarning(
        'captured 0 HTTP exchanges. If the app only uses WebSockets/SSE, or '
        'its traffic did not pass through the browser network stack, the CDP '
        'backend cannot see it.',
      );
    }
    for (final channel in _assembler.nonHttpChannels()) {
      _onWarning('observed non-HTTP channel (out of scope): $channel');
    }
    return exchanges;
  }

  @override
  Future<void> close() async {
    await _ws?.close();
    _ws = null;
    _cdp = null;
  }

  // NOTE: mirrors the page-target discovery in multidev/web_capture.dart;
  // unify into a shared CDP helper if a third consumer appears.
  Future<String> _pageWebSocketUrl(int port) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:$port/json'),
      );
      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      final targets = (jsonDecode(body) as List).cast<Map<String, dynamic>>();
      final page = targets.firstWhere(
        (t) => t['type'] == 'page' && t['webSocketDebuggerUrl'] != null,
        orElse: () => const {},
      );
      final wsUrl = page['webSocketDebuggerUrl'] as String?;
      if (wsUrl == null) {
        throw StateError('No CDP page target on port $port.');
      }
      return wsUrl;
    } finally {
      client.close(force: true);
    }
  }
}

/// Minimal CDP client that correlates `{id}` responses *and* dispatches
/// subscription events to [onEvent] (the request/response-only client in
/// multidev/web_capture.dart drops events).
class _CdpClient {
  _CdpClient(this._ws, {required this.onEvent}) {
    _ws.listen(
      (dynamic data) {
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
        } else if (msg['method'] is String) {
          onEvent(
            msg['method'] as String,
            (msg['params'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
        }
      },
      onError: (Object _) {},
      cancelOnError: false,
    );
  }

  final WebSocket _ws;
  final void Function(String method, Map<String, dynamic> params) onEvent;
  int _nextId = 0;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};

  Future<Map<String, dynamic>> send(
    String method, [
    Map<String, dynamic>? params,
  ]) {
    final id = ++_nextId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _ws.add(jsonEncode({'id': id, 'method': method, 'params': ?params}));
    return completer.future.timeout(const Duration(seconds: 30));
  }
}
