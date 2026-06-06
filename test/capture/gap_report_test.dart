import 'package:test/test.dart';
import 'package:testeador/src/capture/captured_exchange.dart';
import 'package:testeador/src/capture/gap_analysis.dart';
import 'package:testeador/src/capture/gap_report.dart';

CapturedExchange ex(
  String method,
  String url, {
  int? status,
  bool partial = false,
}) => CapturedExchange(
  method: method,
  url: Uri.parse(url),
  requestHeaders: const {},
  responseHeaders: const {},
  status: status,
  partial: partial,
);

void main() {
  group('GapReport.toJson', () {
    test('summarizes gaps grouped by service', () {
      final analysis = GapAnalysis.compute(
        exercised: [
          ex('GET', 'https://a.dev/players', status: 200),
          ex('POST', 'https://b.dev/battles', status: 201),
        ],
      );
      final json = GapReport.toJson(analysis, nonHttpChannels: ['SSE x']);

      expect(json['missingCount'], 2);
      expect(json['coldStart'], isFalse);
      expect((json['services'] as Map).keys, containsAll(['a.dev', 'b.dev']));
      final aDev = (json['services'] as Map)['a.dev'] as List;
      expect(aDev.single, {
        'method': 'GET',
        'path': '/players',
        'status': 200,
        'partial': false,
      });
      expect(json['nonHttpChannels'], ['SSE x']);
    });
  });

  group('GapReport.toHuman', () {
    test('warns on cold-start and lists endpoints by service', () {
      final analysis = GapAnalysis.compute(
        exercised: [ex('GET', 'https://a.dev/players', status: 200)],
        coldStart: true,
      );
      final text = GapReport.toHuman(analysis);

      expect(text, contains('cold-start'));
      expect(text, contains('a.dev'));
      expect(text, contains('GET /players (200)'));
    });

    test('marks partial seeds and lists non-HTTP channels', () {
      final analysis = GapAnalysis.compute(
        exercised: [ex('GET', 'https://a.dev/stream', partial: true)],
      );
      final text = GapReport.toHuman(
        analysis,
        nonHttpChannels: ['WebSocket: wss://a.dev/ws'],
      );

      expect(text, contains('(partial)'));
      expect(text, contains('out of scope: WebSocket: wss://a.dev/ws'));
    });
  });
}
