import 'package:test/test.dart';
import 'package:testeador/testeador.dart';

void main() {
  group('WebDevice', () {
    test('reports the web platform', () {
      expect(WebDevice(baseUrl: 'http://localhost:5000').platform, 'web');
    });

    test('defaults id to chrome and honours an override', () {
      expect(WebDevice(baseUrl: 'http://x').id, 'chrome');
      expect(WebDevice(baseUrl: 'http://x', id: 'admin').id, 'admin');
    });

    test('drives via the chrome patrol device regardless of id', () {
      final web = WebDevice(baseUrl: 'http://x', id: 'admin-panel');
      expect(web.patrolDeviceId, 'chrome');
      expect(
        web.patrolExtraArgs(),
        [
          '--web-headless',
          'true',
          '--web-viewport',
          '{"width": 1280, "height": 900}',
        ],
      );
    });

    test('is a TargetDevice (usable in a DeviceFleet)', () {
      expect(WebDevice(baseUrl: 'http://x'), isA<TargetDevice>());
    });

    group('currentUrl', () {
      test('joins base + default root route', () {
        expect(
          WebDevice(baseUrl: 'http://localhost:5000').currentUrl,
          'http://localhost:5000/',
        );
      });

      test('strips a trailing slash on baseUrl', () {
        expect(
          WebDevice(baseUrl: 'http://localhost:5000/', route: '/players')
              .currentUrl,
          'http://localhost:5000/players',
        );
      });

      test('adds a leading slash to a route missing one', () {
        expect(
          WebDevice(baseUrl: 'http://localhost:5000', route: 'battles')
              .currentUrl,
          'http://localhost:5000/battles',
        );
      });

      test('does not double-slash when both sides carry one', () {
        expect(
          WebDevice(baseUrl: 'http://localhost:5000/', route: '/battles')
              .currentUrl,
          'http://localhost:5000/battles',
        );
      });

      test('reflects a mutated route (per-step re-pointing)', () {
        final web = WebDevice(baseUrl: 'http://localhost:5000');
        expect(web.currentUrl, 'http://localhost:5000/');
        web.route = '/players';
        expect(web.currentUrl, 'http://localhost:5000/players');
        web.route = '/battles';
        expect(web.currentUrl, 'http://localhost:5000/battles');
      });
    });
  });
}
