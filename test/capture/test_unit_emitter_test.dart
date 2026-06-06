import 'package:test/test.dart';
import 'package:testeador/src/capture/captured_exchange.dart';
import 'package:testeador/src/capture/gap_analysis.dart';
import 'package:testeador/src/capture/test_unit_emitter.dart';

EndpointGap gapFor(
  CapturedExchange seed, {
  String? service,
}) => EndpointGap(
  endpoint: seed.endpointId(service: service),
  seed: seed,
);

CapturedExchange exchange({
  String method = 'GET',
  String url = 'https://api.dev/players',
  int? status = 200,
  String? requestBody,
  String? responseBody,
  bool partial = false,
}) => CapturedExchange(
  method: method,
  url: Uri.parse(url),
  requestHeaders: const {},
  responseHeaders: const {},
  requestBody: requestBody,
  status: status,
  responseBody: responseBody,
  partial: partial,
);

void main() {
  group('TestUnitEmitter', () {
    final emitter = TestUnitEmitter();

    test('emits a TestStep builder importing only testeador', () {
      final out = emitter.emit(
        gapFor(exchange(responseBody: '{"id":"1","name":"x"}')),
      );
      expect(out, contains("import 'package:testeador/testeador.dart';"));
      expect(out, contains("import 'package:testeador/expect.dart';"));
      expect(out, isNot(contains('vm_service')));
      expect(out, isNot(contains('marionette')));
      expect(out, contains('TestStep buildGetPlayersContract(Actor actor)'));
      expect(out, contains("await actor.dio.get<dynamic>('/players')"));
      expect(out, contains('expect(response.statusCode, 200);'));
      expect(out, contains("expect(body.containsKey('id'), isTrue);"));
      expect(out, contains("expect(body.containsKey('name'), isTrue);"));
    });

    test('never emits a literal secret from request or response', () {
      final out = emitter.emit(
        gapFor(
          exchange(
            method: 'POST',
            url: 'https://api.dev/register',
            status: 201,
            requestBody: '{"name":"x","password":"PWSECRET"}',
            responseBody: '{"token":"TOKENSECRET","user":{"id":"1"}}',
          ),
        ),
      );
      expect(out, isNot(contains('PWSECRET')));
      expect(out, isNot(contains('TOKENSECRET')));
      expect(out, contains('<redacted>'));
      // Key names (not values) are safe to assert on.
      expect(out, contains("expect(body.containsKey('token'), isTrue);"));
      expect(out, contains("expect(body.containsKey('user'), isTrue);"));
      // POST with a body leaves a TODO instead of embedding the body.
      expect(out, contains('TODO: supply the request body'));
    });

    test('templates the builder name and step name for id paths', () {
      final out = emitter.emit(
        gapFor(exchange(url: 'https://api.dev/users/42', responseBody: '{}')),
      );
      expect(out, contains('buildGetUsersIdContract'));
      expect(out, contains("name: 'GET /users/{id} contract'"));
    });

    test('emits a status TODO when the response was not captured', () {
      final out = emitter.emit(
        gapFor(exchange(status: null, partial: true)),
      );
      expect(out, contains('TODO: response not fully captured'));
      expect(out, isNot(contains('response.statusCode,')));
    });

    test('falls back to dio.request for non-standard methods', () {
      final out = emitter.emit(
        gapFor(exchange(method: 'REPORT', responseBody: '{}')),
      );
      expect(out, contains('actor.dio.request<dynamic>'));
      expect(out, contains("options: Options(method: 'REPORT')"));
    });
  });
}
