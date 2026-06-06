import 'package:test/test.dart';
import 'package:testeador/src/capture/cdp_network_capture.dart';

void main() {
  group('CdpExchangeAssembler', () {
    late CdpExchangeAssembler asm;

    setUp(() => asm = CdpExchangeAssembler());

    Map<String, dynamic> willBeSent(
      String id, {
      String type = 'XHR',
      String method = 'GET',
      String url = 'https://api.dev/users/1',
      Map<String, dynamic> headers = const {},
      String? postData,
    }) => {
      'requestId': id,
      'type': type,
      'request': {
        'url': url,
        'method': method,
        'headers': headers,
        'postData': ?postData,
      },
    };

    Map<String, dynamic> responseReceived(
      String id, {
      int status = 200,
      Map<String, dynamic> headers = const {},
    }) => {
      'requestId': id,
      'response': {'status': status, 'headers': headers},
    };

    test('assembles a full XHR cycle into one exchange', () {
      asm
        ..onRequestWillBeSent(
          willBeSent(
            '1',
            method: 'POST',
            url: 'https://api.dev/players',
            headers: {'Content-Type': 'application/json', 'X-Api-Key': 'k'},
            postData: '{"name":"x"}',
          ),
        )
        ..onResponseReceived(
          responseReceived('1', status: 201, headers: {'Server': 'cf'}),
        )
        ..finalize('1', responseBody: '{"id":"abc"}');

      final ex = asm.exchanges().single;
      expect(ex.method, 'POST');
      expect(ex.url, Uri.parse('https://api.dev/players'));
      expect(ex.requestBody, '{"name":"x"}');
      expect(ex.status, 201);
      expect(ex.responseBody, '{"id":"abc"}');
      expect(ex.partial, isFalse);
    });

    test('lower-cases header keys', () {
      asm
        ..onRequestWillBeSent(willBeSent('1', headers: {'X-Api-Key': 'k'}))
        ..onResponseReceived(
          responseReceived('1', headers: {'Set-Cookie': 'c'}),
        )
        ..finalize('1', responseBody: '{}');

      final ex = asm.exchanges().single;
      expect(ex.requestHeaders['x-api-key'], 'k');
      expect(ex.responseHeaders['set-cookie'], 'c');
    });

    test('ignores non-API resource types', () {
      asm
        ..onRequestWillBeSent(willBeSent('1', type: 'Image'))
        ..onResponseReceived(responseReceived('1'))
        ..finalize('1', responseBody: 'png');
      expect(asm.exchanges(), isEmpty);
    });

    test('records EventSource as a non-HTTP channel, not an exchange', () {
      asm.onRequestWillBeSent(
        willBeSent('1', type: 'EventSource', url: 'https://api.dev/stream'),
      );
      expect(asm.exchanges(), isEmpty);
      expect(asm.nonHttpChannels().single, contains('SSE'));
      expect(asm.nonHttpChannels().single, contains('api.dev/stream'));
    });

    test('records WebSocket creation as a non-HTTP channel', () {
      asm.onWebSocketCreated({'url': 'wss://api.dev/ws'});
      expect(asm.nonHttpChannels().single, contains('WebSocket'));
    });

    test('marks an exchange partial when the response never arrived', () {
      asm
        ..onRequestWillBeSent(willBeSent('1'))
        ..finalize('1');
      final ex = asm.exchanges().single;
      expect(ex.status, isNull);
      expect(ex.partial, isTrue);
    });

    test('markFailed records a partial exchange (endpoint not dropped)', () {
      asm
        ..onRequestWillBeSent(willBeSent('1', url: 'https://api.dev/a'))
        ..markFailed('1');
      expect(asm.exchanges().single.partial, isTrue);
    });

    test('finalize with an explicit partial keeps the body null', () {
      asm
        ..onRequestWillBeSent(willBeSent('1'))
        ..onResponseReceived(responseReceived('1'))
        ..finalize('1', partial: true);
      final ex = asm.exchanges().single;
      expect(ex.partial, isTrue);
      expect(ex.responseBody, isNull);
    });

    test('ignores responseReceived without a matching request', () {
      asm
        ..onResponseReceived(responseReceived('ghost'))
        ..finalize('ghost', responseBody: 'x');
      expect(asm.exchanges(), isEmpty);
    });

    test('finalize is a no-op for an unknown requestId', () {
      asm.finalize('nope', responseBody: 'x');
      expect(asm.exchanges(), isEmpty);
    });

    test('orders exchanges by endpoint identity, not arrival', () {
      asm
        ..onRequestWillBeSent(willBeSent('2', url: 'https://api.dev/zebra'))
        ..onResponseReceived(responseReceived('2'))
        ..finalize('2', responseBody: '{}')
        ..onRequestWillBeSent(willBeSent('1', url: 'https://api.dev/apple'))
        ..onResponseReceived(responseReceived('1'))
        ..finalize('1', responseBody: '{}');

      expect(
        asm.exchanges().map((e) => e.url.path).toList(),
        ['/apple', '/zebra'],
      );
    });

    test('drops malformed events lacking requestId or request', () {
      asm
        ..onRequestWillBeSent({'type': 'XHR'})
        ..onRequestWillBeSent({'requestId': '1'});
      expect(asm.exchanges(), isEmpty);
    });
  });
}
