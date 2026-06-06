import 'package:test/test.dart';
import 'package:testeador/src/contract/endpoint_id.dart';

void main() {
  group('normalizeEndpoint', () {
    EndpointId norm(String method, String url, {String? service}) =>
        normalizeEndpoint(
          method: method,
          url: Uri.parse(url),
          service: service,
        );

    test('upper-cases the method', () {
      expect(norm('get', 'https://x.dev/a').method, 'GET');
      expect(norm('Post', 'https://x.dev/a').method, 'POST');
      expect(norm('GET', 'https://x.dev/a').method, 'GET');
    });

    test('defaults service to the URL host', () {
      expect(
        norm('GET', 'https://api.example.com/a').service,
        'api.example.com',
      );
    });

    test('honors an explicit service over the host', () {
      expect(
        norm('GET', 'https://api.example.com/a', service: 'players').service,
        'players',
      );
    });

    test('templates numeric segments', () {
      expect(
        norm('GET', 'https://x.dev/users/123').templatedPath,
        '/users/{id}',
      );
      expect(
        norm('GET', 'https://x.dev/users/1/posts/2').templatedPath,
        '/users/{id}/posts/{id}',
      );
    });

    test('templates UUID segments', () {
      expect(
        norm(
          'GET',
          'https://x.dev/players/022d582e-6919-465f-a3e4-47278f4245dc',
        ).templatedPath,
        '/players/{id}',
      );
    });

    test('templates long hex segments (mongo/dashless ids)', () {
      expect(
        norm('GET', 'https://x.dev/o/507f1f77bcf86cd799439011').templatedPath,
        '/o/{id}',
      );
    });

    test('leaves ordinary words untouched', () {
      expect(
        norm('GET', 'https://x.dev/api/v2/pokemon/charizard').templatedPath,
        '/api/v2/pokemon/charizard',
      );
    });

    test('does not template short hex segments (< 12 chars)', () {
      // Boundary of the _longHex rule: 8- and 11-char hex slugs stay literal.
      expect(
        norm('GET', 'https://x.dev/t/a3f9b2c1').templatedPath,
        '/t/a3f9b2c1',
      );
      expect(
        norm('GET', 'https://x.dev/t/a3f9b2c1def').templatedPath,
        '/t/a3f9b2c1def',
      );
    });

    test('drops query parameters from identity', () {
      expect(
        norm('GET', 'https://x.dev/users/1?expand=team').templatedPath,
        '/users/{id}',
      );
    });

    test('drops the fragment from identity', () {
      expect(
        norm('GET', 'https://x.dev/users/1#section').templatedPath,
        '/users/{id}',
      );
    });

    test('maps the root path to "/"', () {
      expect(norm('GET', 'https://x.dev/').templatedPath, '/');
      expect(norm('GET', 'https://x.dev').templatedPath, '/');
    });

    test('is idempotent on an already-templated path', () {
      final once = norm('GET', 'https://x.dev/users/1');
      final twice = normalizeEndpoint(
        method: once.method,
        url: Uri.parse('https://${once.service}${once.templatedPath}'),
      );
      expect(twice, once);
    });

    test('collapses distinct ids to the same identity', () {
      expect(
        norm('GET', 'https://x.dev/users/1'),
        norm('GET', 'https://x.dev/users/999'),
      );
    });
  });

  group('EndpointId equality', () {
    const a = EndpointId(method: 'GET', templatedPath: '/u/{id}', service: 's');

    test('equal when all fields match', () {
      const b = EndpointId(
        method: 'GET',
        templatedPath: '/u/{id}',
        service: 's',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs on method, path, or service', () {
      expect(
        a,
        isNot(
          const EndpointId(
            method: 'POST',
            templatedPath: '/u/{id}',
            service: 's',
          ),
        ),
      );
      expect(
        a,
        isNot(
          const EndpointId(method: 'GET', templatedPath: '/x', service: 's'),
        ),
      );
      expect(
        a,
        isNot(
          const EndpointId(
            method: 'GET',
            templatedPath: '/u/{id}',
            service: 't',
          ),
        ),
      );
    });

    test('usable as a set key (equal instances dedupe)', () {
      final pair = [
        a,
        const EndpointId(method: 'GET', templatedPath: '/u/{id}', service: 's'),
      ];
      expect(pair.toSet(), hasLength(1));
    });
  });

  group('EndpointId JSON', () {
    test('round-trips through toJson/fromJson', () {
      const id = EndpointId(
        method: 'POST',
        templatedPath: '/players/{id}',
        service: 'api.dev',
      );
      expect(EndpointId.fromJson(id.toJson()), id);
    });

    test('stores the templated path under the "path" key', () {
      const id = EndpointId(method: 'GET', templatedPath: '/a', service: 's');
      expect(id.toJson(), {'method': 'GET', 'path': '/a', 'service': 's'});
    });

    test('toString is human-readable', () {
      const id = EndpointId(
        method: 'GET',
        templatedPath: '/users/{id}',
        service: 'api.dev',
      );
      expect(id.toString(), 'GET api.dev/users/{id}');
    });
  });
}
