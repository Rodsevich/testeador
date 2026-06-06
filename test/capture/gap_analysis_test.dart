import 'package:test/test.dart';
import 'package:testeador/src/capture/captured_exchange.dart';
import 'package:testeador/src/capture/gap_analysis.dart';
import 'package:testeador/src/contract/endpoint_id.dart';

CapturedExchange ex(String method, String url, {int? status}) =>
    CapturedExchange(
      method: method,
      url: Uri.parse(url),
      requestHeaders: const {},
      responseHeaders: const {},
      status: status,
    );

void main() {
  group('GapAnalysis.compute', () {
    test('reports only exercised endpoints not in the covered set', () {
      final analysis = GapAnalysis.compute(
        exercised: [
          ex('GET', 'https://api.dev/players', status: 200),
          ex('POST', 'https://api.dev/battles', status: 201),
        ],
        covered: {
          const EndpointId(
            method: 'GET',
            templatedPath: '/players',
            service: 'api.dev',
          ),
        },
      );

      expect(analysis.coldStart, isFalse);
      expect(analysis.gaps, hasLength(1));
      expect(analysis.gaps.single.endpoint.templatedPath, '/battles');
    });

    test('collapses repeated calls to one gap, seeding the last 2xx', () {
      final analysis = GapAnalysis.compute(
        exercised: [
          ex('GET', 'https://api.dev/players/1', status: 404),
          ex('GET', 'https://api.dev/players/2', status: 200),
        ],
      );

      expect(analysis.gaps, hasLength(1));
      expect(analysis.gaps.single.endpoint.templatedPath, '/players/{id}');
      expect(analysis.gaps.single.seed.status, 200);
    });

    test('collapses a 401 -> retry onto the successful call', () {
      final analysis = GapAnalysis.compute(
        exercised: [
          ex('GET', 'https://api.dev/me', status: 401),
          ex('GET', 'https://api.dev/me', status: 200),
        ],
      );
      expect(analysis.gaps.single.seed.status, 200);
    });

    test('cold-start surfaces every endpoint and sets the flag', () {
      final analysis = GapAnalysis.compute(
        exercised: [ex('GET', 'https://api.dev/players', status: 200)],
        covered: {
          const EndpointId(
            method: 'GET',
            templatedPath: '/players',
            service: 'api.dev',
          ),
        },
        coldStart: true,
      );
      // covered is ignored in cold-start: the endpoint is still a candidate.
      expect(analysis.coldStart, isTrue);
      expect(analysis.gaps, hasLength(1));
    });

    test('groups gaps by service', () {
      final analysis = GapAnalysis.compute(
        exercised: [
          ex('GET', 'https://a.dev/x', status: 200),
          ex('GET', 'https://b.dev/y', status: 200),
        ],
      );
      expect(analysis.byService().keys, containsAll(['a.dev', 'b.dev']));
    });

    test('orders gaps deterministically by identity', () {
      final analysis = GapAnalysis.compute(
        exercised: [
          ex('GET', 'https://api.dev/zebra', status: 200),
          ex('GET', 'https://api.dev/apple', status: 200),
        ],
      );
      expect(
        analysis.gaps.map((g) => g.endpoint.templatedPath).toList(),
        ['/apple', '/zebra'],
      );
    });
  });

  group('GapAnalysis.selectSeed', () {
    test('falls back to the last with a status when none are 2xx', () {
      final seed = GapAnalysis.selectSeed([
        ex('GET', 'https://api.dev/a', status: 500),
        ex('GET', 'https://api.dev/a', status: 404),
      ]);
      expect(seed.status, 404);
    });

    test('falls back to the last seen when no status is known', () {
      final last = ex('GET', 'https://api.dev/a');
      final seed = GapAnalysis.selectSeed([
        ex('GET', 'https://api.dev/a'),
        last,
      ]);
      expect(identical(seed, last), isTrue);
    });
  });
}
