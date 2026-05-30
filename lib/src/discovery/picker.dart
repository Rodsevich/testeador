import 'package:testeador/src/codegen/aggregator.dart';
import 'package:testeador/src/codegen/identifier_naming.dart';
import 'package:testeador/src/codegen/registry.dart';

/// A single test entry surfaced by [DiscoveredCatalog].
///
/// Carries everything a downstream picker or flow emitter needs:
///
/// - [fqId] / [identifier] for static `TestInjector.<identifier>` references;
/// - [packageName] / [sourceUri] for displaying file locations;
/// - [name] / [groupChain] / [tags] for human-readable filtering.
class DiscoveredEntry {
  /// Builds an entry.
  DiscoveredEntry({
    required this.packageName,
    required this.sourceUri,
    required this.groupChain,
    required this.name,
    required this.tags,
    required this.identifier,
  });

  /// Owning package of the captured test.
  final String packageName;

  /// Package-relative path of the source `*_test.dart`.
  final String sourceUri;

  /// Enclosing `group()` chain, outermost first.
  final List<String> groupChain;

  /// Literal first argument of the `test()` call.
  final String name;

  /// Union of test- and group-level tags.
  final Set<String> tags;

  /// Dart identifier matching the static getter generated in
  /// `lib/test_injector.g.dart` (`TestInjector.<identifier>`).
  final String identifier;

  /// `<package>:<group1>/<group2>/.../<name>`, collapsed when there are no
  /// enclosing groups. Mirrors [CapturedTest.fqId].
  String get fqId {
    final groups = groupChain.join('/');
    return groups.isEmpty
        ? '$packageName:$name'
        : '$packageName:$groups/$name';
  }

  /// JSON-friendly representation used by the CLI/MCP layers.
  Map<String, Object?> toJson() => {
    'fqId': fqId,
    'identifier': identifier,
    'package': packageName,
    'sourceUri': sourceUri,
    'name': name,
    'groupChain': groupChain,
    'tags': tags.toList()..sort(),
  };
}

/// Flattened, queryable view over every captured test reachable from a set
/// of [FileManifest]s.
///
/// The identifier assignment uses the exact same [IdentifierNamer] the
/// aggregator uses, traversed in the same package → source-path order, so a
/// picker's identifier value is guaranteed to match the static getter name
/// emitted in `lib/test_injector.g.dart`.
class DiscoveredCatalog {
  /// Builds a catalog from a list of parsed manifests.
  factory DiscoveredCatalog.fromManifests(List<FileManifest> manifests) {
    final sorted = [...manifests]..sort((a, b) {
      final byPkg = a.packageName.compareTo(b.packageName);
      if (byPkg != 0) return byPkg;
      return a.sourceRelativePath.compareTo(b.sourceRelativePath);
    });
    final namer = IdentifierNamer();
    final entries = <DiscoveredEntry>[];
    final seen = <String>{};
    for (final m in sorted) {
      for (final dt in m.tests) {
        final captured = CapturedTest(
          packageName: m.packageName,
          sourceUri: m.sourceRelativePath,
          groupChain: dt.groupChain,
          name: dt.name,
          tags: dt.tags,
          setUps: const [],
          tearDowns: const [],
          body: _noBody,
        );
        if (!seen.add(captured.fqId)) {
          // Duplicate fqId across packages: the aggregator already emits a
          // warning and shadows the second occurrence. Mirror that here.
          continue;
        }
        final id = namer.assign(captured);
        entries.add(
          DiscoveredEntry(
            packageName: m.packageName,
            sourceUri: m.sourceRelativePath,
            groupChain: dt.groupChain,
            name: dt.name,
            tags: dt.tags,
            identifier: id,
          ),
        );
      }
    }
    return DiscoveredCatalog._(entries);
  }

  DiscoveredCatalog._(this.entries);

  /// All discovered entries, in stable order (package → source path →
  /// declaration order).
  final List<DiscoveredEntry> entries;

  /// Entries whose tag set contains [tag].
  List<DiscoveredEntry> filterByTag(String tag) =>
      entries.where((e) => e.tags.contains(tag)).toList();

  /// Entries whose `fqId` matches [pattern] (`String.contains` for strings,
  /// `RegExp.hasMatch` for regexes).
  List<DiscoveredEntry> filterByPattern(Pattern pattern) =>
      entries.where((e) => _matches(pattern, e.fqId)).toList();

  /// Selects entries in [fqIds]'s order. Throws [UnknownFqIdException] if any
  /// fqId is unknown — used by `--pick` so a typo fails loudly rather than
  /// silently producing an empty flow.
  List<DiscoveredEntry> selectByFqIds(List<String> fqIds) {
    final byId = {for (final e in entries) e.fqId: e};
    final out = <DiscoveredEntry>[];
    final missing = <String>[];
    for (final id in fqIds) {
      final e = byId[id];
      if (e == null) {
        missing.add(id);
      } else {
        out.add(e);
      }
    }
    if (missing.isNotEmpty) {
      throw UnknownFqIdException(
        missing: missing,
        knownSample: entries.take(5).map((e) => e.fqId).toList(),
      );
    }
    return out;
  }

  static bool _matches(Pattern p, String input) {
    if (p is RegExp) return p.hasMatch(input);
    if (p is String) return input.contains(p);
    return p.allMatches(input).isNotEmpty;
  }
}

void _noBody() {}

/// Thrown by [DiscoveredCatalog.selectByFqIds] when a requested fqId is not
/// present in the catalog. Carries the missing ids plus a small sample of
/// known ones so the message stays self-explanatory at the CLI.
class UnknownFqIdException implements Exception {
  /// Builds the exception.
  UnknownFqIdException({required this.missing, required this.knownSample});

  /// fqIds that were requested but not found.
  final List<String> missing;

  /// Up to five fqIds that *do* exist, for hinting in the error message.
  final List<String> knownSample;

  /// User-facing message ready to be printed to stderr.
  String get message {
    final sample = knownSample.map((s) => '"$s"').join(', ');
    return 'No captured test matches the following fqId(s):\n'
        '  ${missing.join('\n  ')}\n'
        'Known fqIds (sample): $sample.';
  }

  @override
  String toString() => message;
}
