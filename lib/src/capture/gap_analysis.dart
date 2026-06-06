import 'package:meta/meta.dart';
import 'package:testeador/src/capture/captured_exchange.dart';
import 'package:testeador/src/contract/endpoint_id.dart';

/// One uncovered endpoint plus the representative exchange used to seed its
/// generated contract test.
@immutable
class EndpointGap {
  /// Creates a gap.
  const EndpointGap({required this.endpoint, required this.seed});

  /// The endpoint with no existing coverage.
  final EndpointId endpoint;

  /// The exchange chosen to seed the test (see [GapAnalysis] for the rule).
  final CapturedExchange seed;
}

/// The result of diffing the endpoints a real app *exercised* against the
/// endpoints existing tests *cover*.
///
/// [gaps] are the uncovered endpoints (deduplicated, one per identity, sorted).
/// [coldStart] is `true` when there was no coverage baseline at all — every
/// exercised endpoint is then surfaced as a *candidate* and the caller must
/// warn rather than silently generate the whole surface.
@immutable
class GapAnalysis {
  /// Creates an analysis result.
  const GapAnalysis({required this.gaps, required this.coldStart});

  /// Diffs [exercised] exchanges against the [covered] endpoint set.
  ///
  /// Exchanges are grouped by [EndpointId]; each group collapses to a single
  /// seed using [selectSeed] (prefer the last 2xx — this also discards the
  /// `401` of a `401 → token-refresh → retry` sequence in favour of the
  /// successful retry). When [coldStart] is `true`, [covered] is ignored and
  /// every exercised endpoint becomes a candidate gap.
  factory GapAnalysis.compute({
    required List<CapturedExchange> exercised,
    Set<EndpointId> covered = const {},
    bool coldStart = false,
  }) {
    final grouped = <EndpointId, List<CapturedExchange>>{};
    for (final ex in exercised) {
      (grouped[ex.endpointId()] ??= []).add(ex);
    }

    final gaps = <EndpointGap>[];
    grouped.forEach((endpoint, group) {
      if (!coldStart && covered.contains(endpoint)) return;
      gaps.add(EndpointGap(endpoint: endpoint, seed: selectSeed(group)));
    });
    gaps.sort((a, b) => a.endpoint.toString().compareTo(b.endpoint.toString()));

    return GapAnalysis(gaps: gaps, coldStart: coldStart);
  }

  /// Uncovered endpoints, ordered by identity.
  final List<EndpointGap> gaps;

  /// Whether the coverage baseline was absent (cold-start).
  final bool coldStart;

  /// Groups [gaps] by service/host (microservice-level coverage view).
  Map<String, List<EndpointGap>> byService() {
    final out = <String, List<EndpointGap>>{};
    for (final gap in gaps) {
      (out[gap.endpoint.service] ??= []).add(gap);
    }
    return out;
  }

  /// Picks the seed exchange for one endpoint's observations: the last `2xx`
  /// if any, else the last with a known status, else the last seen. Keeping
  /// "last 2xx" collapses retry sequences onto the successful call.
  static CapturedExchange selectSeed(List<CapturedExchange> group) {
    CapturedExchange? lastOk;
    CapturedExchange? lastWithStatus;
    for (final ex in group) {
      final status = ex.status;
      if (status != null) {
        lastWithStatus = ex;
        if (status >= 200 && status < 300) lastOk = ex;
      }
    }
    return lastOk ?? lastWithStatus ?? group.last;
  }
}
