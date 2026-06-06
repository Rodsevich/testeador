import 'package:test/test.dart';
import 'package:testeador/src/capture/captured_exchange.dart';
import 'package:testeador/src/capture/recording_session.dart';
import 'package:testeador/src/capture/traffic_capture.dart';

/// In-memory [TrafficCapture] stub feeding canned exchanges — a fixture, not a
/// mock of the system under test (the session is what's tested here).
class _StubCapture implements TrafficCapture {
  _StubCapture(this._exchanges);

  final List<CapturedExchange> _exchanges;
  bool opened = false;
  bool closed = false;

  @override
  Future<void> open() async => opened = true;

  @override
  Future<List<CapturedExchange>> takeExchanges() async => _exchanges;

  @override
  Future<void> close() async => closed = true;
}

CapturedExchange ex(String method, String url, {int? status}) =>
    CapturedExchange(
      method: method,
      url: Uri.parse(url),
      requestHeaders: const {},
      responseHeaders: const {},
      status: status,
    );

void main() {
  group('RecordingSession', () {
    test('opens, drains, closes and generates one unit per gap', () async {
      final capture = _StubCapture([
        ex('POST', 'https://api.dev/players', status: 201),
        ex('GET', 'https://api.dev/players/7', status: 200),
      ]);
      final session = RecordingSession(capture, coldStart: true);

      await session.start();
      expect(capture.opened, isTrue);

      final outcome = await session.stopAndGenerate();
      expect(capture.closed, isTrue);
      expect(outcome.analysis.coldStart, isTrue);
      expect(outcome.units, hasLength(2));
      expect(outcome.reportJson['missingCount'], 2);
      expect(outcome.reportText, contains('uncovered endpoint'));
    });

    test('derives snake_case file names from the endpoint identity', () async {
      final capture = _StubCapture([
        ex('GET', 'https://api.dev/users/42', status: 200),
      ]);
      final outcome = await RecordingSession(
        capture,
        coldStart: true,
      ).stopAndGenerate();

      expect(outcome.units.single.fileName, 'get_users_id_contract.dart');
      expect(outcome.units.single.source, contains('TestStep'));
    });

    test('emits nothing when no traffic was captured', () async {
      final outcome = await RecordingSession(
        _StubCapture([]),
        coldStart: true,
      ).stopAndGenerate();
      expect(outcome.units, isEmpty);
      expect(outcome.analysis.gaps, isEmpty);
    });
  });
}
