import 'dart:convert';

/// One actor's cURL log block extracted from a `Testeador.run` stdout/stderr.
class ActorCurlLog {
  /// Creates an [ActorCurlLog] for [actor] containing [curls].
  const ActorCurlLog({required this.actor, required this.curls});

  /// Actor name as printed in `cURL log for actor "<name>":`.
  final String actor;

  /// Recorded cURL commands, in the order they were issued.
  final List<String> curls;

  /// JSON-friendly representation for MCP tool responses.
  Map<String, dynamic> toJson() => {'actor': actor, 'curls': curls};
}

/// Parses [output] (typically the merged stdout+stderr of a testeador run)
/// looking for blocks of the shape:
///
/// ```text
///   cURL log for actor "Firesh":
///     curl -X GET ...
///     curl -X POST ...
/// ```
///
/// This format is produced by `Testeador._printCurlLogs` in
/// `lib/src/testeador.dart`. If that format changes, the regex below must be
/// updated. A future-proof alternative is a `--curl-json` flag on testeador.
List<ActorCurlLog> parseCurlLogs(String output) {
  final lines = const LineSplitter().convert(output);
  final result = <ActorCurlLog>[];
  String? currentActor;
  var currentCurls = <String>[];

  final header = RegExp('cURL log for actor "([^"]+)":');

  for (final line in lines) {
    final match = header.firstMatch(line);
    if (match != null) {
      if (currentActor != null && currentCurls.isNotEmpty) {
        result.add(ActorCurlLog(actor: currentActor, curls: currentCurls));
      }
      currentActor = match.group(1);
      currentCurls = <String>[];
      continue;
    }

    if (currentActor == null) continue;

    final trimmed = line.trimLeft();
    if (trimmed.startsWith('curl ')) {
      currentCurls.add(trimmed);
    } else if (trimmed.isEmpty && currentCurls.isEmpty) {
      // skip leading blank line inside the block
    } else if (trimmed.isEmpty) {
      // blank line after at least one curl ends the block
      result.add(ActorCurlLog(actor: currentActor, curls: currentCurls));
      currentActor = null;
      currentCurls = <String>[];
    }
  }

  if (currentActor != null && currentCurls.isNotEmpty) {
    result.add(ActorCurlLog(actor: currentActor, curls: currentCurls));
  }

  return result;
}

/// Best-effort extraction of `N/M flows passed.` from a testeador run.
///
/// Returns `null` when the summary line cannot be located.
({int passed, int total})? parseRunSummary(String output) {
  final match =
      RegExp(r'(\d+)/(\d+)\s+flows\s+passed\b').firstMatch(output);
  if (match == null) return null;
  return (
    passed: int.parse(match.group(1)!),
    total: int.parse(match.group(2)!),
  );
}
