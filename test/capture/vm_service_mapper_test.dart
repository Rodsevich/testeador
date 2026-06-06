import 'dart:convert';

import 'package:test/test.dart';
import 'package:testeador/src/capture/vm_service_capture.dart';

void main() {
  group('mapVmHttpExchange', () {
    test('maps a full native exchange', () {
      final ex = mapVmHttpExchange(
        method: 'POST',
        uri: Uri.parse('https://api.dev/players'),
        requestHeaders: {'content-type': 'application/json'},
        requestBody: utf8.encode('{"name":"x"}'),
        statusCode: 201,
        responseHeaders: {'server': 'cf'},
        responseBody: utf8.encode('{"id":"abc"}'),
      );

      expect(ex.method, 'POST');
      expect(ex.url, Uri.parse('https://api.dev/players'));
      expect(ex.requestBody, '{"name":"x"}');
      expect(ex.status, 201);
      expect(ex.responseBody, '{"id":"abc"}');
      expect(ex.partial, isFalse);
    });

    test('flattens multi-valued headers and lower-cases keys', () {
      final ex = mapVmHttpExchange(
        method: 'GET',
        uri: Uri.parse('https://api.dev/a'),
        responseHeaders: {
          'Set-Cookie': ['a=1', 'b=2'],
          'X-Trace': 'z',
        },
      );

      expect(ex.responseHeaders['set-cookie'], 'a=1, b=2');
      expect(ex.responseHeaders['x-trace'], 'z');
    });

    test('treats a null status as a partial exchange', () {
      final ex = mapVmHttpExchange(
        method: 'GET',
        uri: Uri.parse('https://api.dev/a'),
      );
      expect(ex.status, isNull);
      expect(ex.partial, isTrue);
    });

    test('decodes empty bodies as null', () {
      final ex = mapVmHttpExchange(
        method: 'GET',
        uri: Uri.parse('https://api.dev/a'),
        statusCode: 200,
        requestBody: const [],
        responseBody: const [],
      );
      expect(ex.requestBody, isNull);
      expect(ex.responseBody, isNull);
    });

    test('returns null for undecodable (non-UTF8) bodies', () {
      final ex = mapVmHttpExchange(
        method: 'GET',
        uri: Uri.parse('https://api.dev/a'),
        statusCode: 200,
        responseBody: const [0xff, 0xfe, 0xfd],
      );
      expect(ex.responseBody, isNull);
    });

    test('null header maps become empty', () {
      final ex = mapVmHttpExchange(
        method: 'GET',
        uri: Uri.parse('https://api.dev/a'),
        statusCode: 200,
      );
      expect(ex.requestHeaders, isEmpty);
      expect(ex.responseHeaders, isEmpty);
    });

    test('endpointId on the mapped exchange templates the path', () {
      final ex = mapVmHttpExchange(
        method: 'get',
        uri: Uri.parse('https://api.dev/users/42'),
        statusCode: 200,
      );
      expect(ex.endpointId().templatedPath, '/users/{id}');
      expect(ex.endpointId().method, 'GET');
    });
  });
}
