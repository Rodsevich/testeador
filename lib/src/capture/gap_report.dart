import 'package:testeador/src/capture/gap_analysis.dart';

/// Renders a [GapAnalysis] as a machine-readable map and a human summary,
/// grouped by microservice. Pure — no I/O — so it is unit-tested directly.
abstract final class GapReport {
  /// JSON-encodable view: cold-start flag, total, per-service endpoint list,
  /// and any observed out-of-scope channels.
  static Map<String, dynamic> toJson(
    GapAnalysis analysis, {
    List<String> nonHttpChannels = const [],
  }) {
    final services = <String, dynamic>{};
    analysis.byService().forEach((service, gaps) {
      services[service] = [
        for (final gap in gaps)
          {
            'method': gap.endpoint.method,
            'path': gap.endpoint.templatedPath,
            'status': gap.seed.status,
            'partial': gap.seed.partial,
          },
      ];
    });
    return {
      'coldStart': analysis.coldStart,
      'missingCount': analysis.gaps.length,
      'services': services,
      'nonHttpChannels': nonHttpChannels,
    };
  }

  /// Human summary suitable for a CLI/MCP response.
  static String toHuman(
    GapAnalysis analysis, {
    List<String> nonHttpChannels = const [],
  }) {
    final buffer = StringBuffer();
    if (analysis.coldStart) {
      buffer.writeln(
        '⚠ cold-start: no coverage baseline — every exercised endpoint is a '
        'candidate (annotate coverage to narrow this).',
      );
    }
    buffer.writeln('${analysis.gaps.length} uncovered endpoint(s):');
    analysis.byService().forEach((service, gaps) {
      buffer.writeln('  $service');
      for (final gap in gaps) {
        final status = gap.seed.partial
            ? 'partial'
            : '${gap.seed.status ?? '?'}';
        buffer.writeln(
          '    ${gap.endpoint.method} ${gap.endpoint.templatedPath} '
          '($status)',
        );
      }
    });
    for (final channel in nonHttpChannels) {
      buffer.writeln('  out of scope: $channel');
    }
    return buffer.toString();
  }
}
