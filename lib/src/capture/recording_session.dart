import 'package:testeador/src/capture/gap_analysis.dart';
import 'package:testeador/src/capture/gap_report.dart';
import 'package:testeador/src/capture/test_unit_emitter.dart';
import 'package:testeador/src/capture/traffic_capture.dart';
import 'package:testeador/src/contract/endpoint_id.dart';

/// A generated contract-test unit: a suggested file name and its Dart source.
class GeneratedUnit {
  /// Creates a generated unit.
  const GeneratedUnit({required this.fileName, required this.source});

  /// Suggested snake_case file name, e.g. `post_players_contract.dart`.
  final String fileName;

  /// The Dart source produced by [TestUnitEmitter].
  final String source;
}

/// Everything a `stop_and_generate` produces: the diff, the report (machine +
/// human), and one draft unit per uncovered endpoint.
class RecordingOutcome {
  /// Creates an outcome.
  const RecordingOutcome({
    required this.analysis,
    required this.reportJson,
    required this.reportText,
    required this.units,
  });

  /// The computed gap.
  final GapAnalysis analysis;

  /// Machine-readable report ([GapReport.toJson]).
  final Map<String, dynamic> reportJson;

  /// Human summary ([GapReport.toHuman]).
  final String reportText;

  /// One draft test per gap.
  final List<GeneratedUnit> units;
}

/// Brackets a capture session: [start] opens the [TrafficCapture] (which
/// enables profiling before the journey), then — after the app has been
/// exercised by a human or an AI — [stopAndGenerate] drains the traffic,
/// diffs it against the coverage baseline, and emits the missing tests.
///
/// The driver in between is irrelevant; capture is passive. This is the single
/// core shared by the `record` CLI and the MCP `start_recording` /
/// `stop_and_generate` tools.
class RecordingSession {
  /// Wraps `capture` with the `covered` baseline and an `emitter`.
  ///
  /// `coldStart` should be `true` when no coverage annotations exist yet, so
  /// the outcome flags that every endpoint is a candidate.
  RecordingSession(
    this._capture, {
    Set<EndpointId> covered = const {},
    bool coldStart = false,
    TestUnitEmitter? emitter,
  }) : _covered = covered,
       _coldStart = coldStart,
       _emitter = emitter ?? TestUnitEmitter();

  final TrafficCapture _capture;
  final Set<EndpointId> _covered;
  final bool _coldStart;
  final TestUnitEmitter _emitter;

  /// Opens capture. Call before the journey.
  Future<void> start() => _capture.open();

  /// Drains traffic, closes capture, computes the gap, and generates units.
  Future<RecordingOutcome> stopAndGenerate() async {
    final exchanges = await _capture.takeExchanges();
    await _capture.close();

    final analysis = GapAnalysis.compute(
      exercised: exchanges,
      covered: _covered,
      coldStart: _coldStart,
    );

    final units = [
      for (final gap in analysis.gaps)
        GeneratedUnit(
          fileName: _fileName(gap.endpoint),
          source: _emitter.emit(gap),
        ),
    ];

    return RecordingOutcome(
      analysis: analysis,
      reportJson: GapReport.toJson(analysis),
      reportText: GapReport.toHuman(analysis),
      units: units,
    );
  }

  String _fileName(EndpointId endpoint) {
    final slug = [
      endpoint.method.toLowerCase(),
      ...endpoint.templatedPath.split('/').where((s) => s.isNotEmpty),
    ].map((part) => part.replaceAll(RegExp('[^a-z0-9]+'), '_')).join('_');
    final trimmed = slug
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(
          RegExp(r'^_|_$'),
          '',
        );
    return '${trimmed}_contract.dart';
  }
}
