import 'package:test/test.dart';
import 'package:testeador/src/mcp/curl_parser.dart';

void main() {
  group('parseCurlLogs', () {
    test('extracts one block per actor', () {
      const output = '''
testeador — running 1 flow(s)

▶ My flow
  ✗ FAILED: bad response

  cURL log for actor "Firesh":
    curl -X GET 'https://api.example.com/a'
    curl -X POST 'https://api.example.com/b'

  cURL log for actor "Watersh":
    curl -X GET 'https://api.example.com/c'

1/2 flows passed.
''';
      final logs = parseCurlLogs(output);
      expect(logs, hasLength(2));
      expect(logs[0].actor, 'Firesh');
      expect(logs[0].curls, hasLength(2));
      expect(logs[0].curls.first, startsWith('curl -X GET'));
      expect(logs[1].actor, 'Watersh');
      expect(logs[1].curls, hasLength(1));
    });

    test('returns empty when no cURL blocks present', () {
      expect(parseCurlLogs('nothing here'), isEmpty);
    });

    test('handles a trailing block with no blank line after it', () {
      const output = 'cURL log for actor "Solo":\n'
          "    curl -X GET 'https://x'";
      final logs = parseCurlLogs(output);
      expect(logs, hasLength(1));
      expect(logs.single.actor, 'Solo');
      expect(logs.single.curls, hasLength(1));
    });
  });

  group('parseRunSummary', () {
    test('parses N/M flows passed', () {
      final s = parseRunSummary('\n3/5 flows passed.\n');
      expect(s, isNotNull);
      expect(s!.passed, 3);
      expect(s.total, 5);
    });

    test('returns null when summary absent', () {
      expect(parseRunSummary('no summary'), isNull);
    });
  });
}
