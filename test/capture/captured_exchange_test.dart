import 'package:test/test.dart';
import 'package:testeador/src/capture/captured_exchange.dart';
import 'package:testeador/src/contract/endpoint_id.dart';

void main() {
  group('CapturedExchange', () {
    CapturedExchange make({
      String method = 'GET',
      String url = 'https://api.dev/users/1',
      int? status = 200,
      bool partial = false,
    }) => CapturedExchange(
      method: method,
      url: Uri.parse(url),
      requestHeaders: const {},
      responseHeaders: const {},
      status: status,
      partial: partial,
    );

    test('exposes the request host', () {
      expect(make(url: 'https://api.example.com/x').host, 'api.example.com');
    });

    test('endpointId normalizes method, templates path, defaults service', () {
      expect(
        make(method: 'post', url: 'https://api.dev/users/42').endpointId(),
        const EndpointId(
          method: 'POST',
          templatedPath: '/users/{id}',
          service: 'api.dev',
        ),
      );
    });

    test('endpointId honors an explicit service', () {
      expect(make().endpointId(service: 'users-svc').service, 'users-svc');
    });

    test('partial defaults to false', () {
      expect(make().partial, isFalse);
    });

    test('toString shows status, pending and partial markers', () {
      expect(make().toString(), contains('-> 200'));
      expect(make(status: null).toString(), contains('(pending)'));
      expect(make(partial: true).toString(), contains('[partial]'));
    });
  });
}
