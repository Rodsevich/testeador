import 'dart:convert';

import 'package:testeador/src/codegen/identifier_naming.dart';
import 'package:testeador/src/codegen/registry.dart';
import 'package:testeador/src/codegen/scanner.dart';
import 'package:testeador/src/contract/endpoint_id.dart';

/// Per-`*_test.dart` manifest produced by the per-package capture builder
/// and read back by the aggregator.
class FileManifest {
  /// Builds a manifest.
  FileManifest({
    required this.packageName,
    required this.sourceRelativePath,
    required this.transformedImport,
    required this.entryPointName,
    required this.tests,
  });

  /// Hydrates a manifest from its JSON form (see [toJson]).
  factory FileManifest.fromJson(Map<String, dynamic> json) {
    return FileManifest(
      packageName: json['packageName'] as String,
      sourceRelativePath: json['sourceRelativePath'] as String,
      transformedImport: json['transformedImport'] as String,
      entryPointName: json['entryPointName'] as String,
      tests: (json['tests'] as List)
          .cast<Map<String, dynamic>>()
          .map(
            (t) => DiscoveredTest(
              name: t['name'] as String,
              groupChain: (t['groupChain'] as List).cast<String>(),
              tags: (t['tags'] as List).cast<String>().toSet(),
              coveredEndpoints: _coveredEndpointsFromJson(t),
            ),
          )
          .toList(),
    );
  }

  /// Owning package of the captured file.
  final String packageName;

  /// Path of the source file relative to its package root, e.g.
  /// `test/foo_test.dart`. Used to form `CapturedTest.sourceUri`.
  final String sourceRelativePath;

  /// `package:<pkg>/...` URI of the transformed copy, which the aggregator
  /// imports with a unique prefix so it can call its `$entry`.
  final String transformedImport;

  /// Name of the renamed `main()` function inside the transformed file
  /// (`_testeadorCapture$<hash>`). Stored only for documentation; the
  /// aggregator only needs the `$entry` constant exposed by every
  /// transformed file.
  final String entryPointName;

  /// Tests detected statically by the scanner. Used to drive identifier
  /// generation in `TestInjector`.
  final List<DiscoveredTest> tests;

  /// JSON form persisted in the per-package manifest asset.
  Map<String, dynamic> toJson() => {
    'packageName': packageName,
    'sourceRelativePath': sourceRelativePath,
    'transformedImport': transformedImport,
    'entryPointName': entryPointName,
    'tests': tests.map(_testToJson).toList(),
  };

  /// Convenience: serializes [manifests] as a single JSON document (one
  /// entry per file).
  static String encodeAll(Iterable<FileManifest> manifests) =>
      const JsonEncoder.withIndent(
        '  ',
      ).convert(manifests.map((m) => m.toJson()).toList());

  /// Inverse of [encodeAll].
  static List<FileManifest> decodeAll(String json) => (jsonDecode(json) as List)
      .cast<Map<String, dynamic>>()
      .map(FileManifest.fromJson)
      .toList();
}

/// Result of [generateTestInjector].
class AggregationResult {
  /// Builds a result.
  AggregationResult({required this.source, required this.warnings});

  /// Full source of the generated `test_injector.g.dart`.
  final String source;

  /// Diagnostics surfaced during aggregation (e.g. identifier collisions
  /// resolved by hash suffix).
  final List<String> warnings;
}

/// Produces the contents of `lib/test_injector.g.dart` from a flat list of
/// per-file manifests collected across the root package and any
/// dependency package that ran the capture builder.
///
/// The returned source is a self-contained library (no `part of`) that
/// declares a `TestInjector` class with:
/// - one static `TestStep get <id>` per discovered test;
/// - `byName`, `byTags`, `byRegExp` dynamic queries;
/// - a private `_registry` initialized by running each file's `$entry()`.
///
/// Consumers import it directly: `import 'package:<pkg>/test_injector.g.dart';`.
AggregationResult generateTestInjector({
  required List<FileManifest> manifests,
}) {
  final warnings = <String>[];
  final namer = IdentifierNamer();

  // Stable ordering: by package, then by source path, then declaration order.
  manifests.sort((a, b) {
    final byPkg = a.packageName.compareTo(b.packageName);
    if (byPkg != 0) return byPkg;
    return a.sourceRelativePath.compareTo(b.sourceRelativePath);
  });

  final fileEntries = <_FileEntry>[];
  for (var i = 0; i < manifests.length; i++) {
    fileEntries.add(_FileEntry(manifest: manifests[i], importPrefix: '_f$i'));
  }

  final allFqIds = <String, _TestRef>{};
  for (final fe in fileEntries) {
    for (final dt in fe.manifest.tests) {
      final captured = _capturedFromDiscovered(fe.manifest, dt);
      final id = namer.assign(captured);
      if (allFqIds.containsKey(captured.fqId)) {
        warnings.add(
          'duplicate fqId "${captured.fqId}"; second occurrence in '
          '${fe.manifest.packageName}:${fe.manifest.sourceRelativePath} '
          'shadows the first.',
        );
        continue;
      }
      allFqIds[captured.fqId] = _TestRef(
        identifier: id,
        captured: captured,
        fileEntry: fe,
      );
    }
  }

  final source = _emit(
    fileEntries: fileEntries,
    testRefs: allFqIds.values.toList(),
  );
  return AggregationResult(source: source, warnings: warnings);
}

CapturedTest _capturedFromDiscovered(FileManifest manifest, DiscoveredTest dt) {
  // Tags/setUps/tearDowns/body are not needed for naming or fqId — the
  // aggregator only needs identity. We fill the closures with no-ops; the
  // real values are filled when `runCapture` executes the file's `$entry`.
  return CapturedTest(
    packageName: manifest.packageName,
    sourceUri: manifest.sourceRelativePath,
    groupChain: dt.groupChain,
    name: dt.name,
    tags: dt.tags,
    setUps: const [],
    tearDowns: const [],
    body: () {},
  );
}

class _FileEntry {
  _FileEntry({required this.manifest, required this.importPrefix});
  final FileManifest manifest;
  final String importPrefix;
}

class _TestRef {
  _TestRef({
    required this.identifier,
    required this.captured,
    required this.fileEntry,
  });
  final String identifier;
  final CapturedTest captured;
  final _FileEntry fileEntry;
}

String _emit({
  required List<_FileEntry> fileEntries,
  required List<_TestRef> testRefs,
}) {
  final b = StringBuffer()
    ..writeln('// GENERATED CODE — DO NOT MODIFY BY HAND.')
    ..writeln('// Produced by testeador codegen.')
    ..writeln('// ignore_for_file: type=lint')
    ..writeln()
    ..writeln("import 'package:testeador/codegen.dart';")
    ..writeln("import 'package:testeador/testeador.dart';");
  for (final fe in fileEntries) {
    b.writeln(
      "import '${fe.manifest.transformedImport}' as ${fe.importPrefix};",
    );
  }
  b.writeln();

  for (final fe in fileEntries) {
    final note =
        '// Captured from ${fe.manifest.packageName}:'
        '${fe.manifest.sourceRelativePath}';
    b.writeln(note);
  }
  b
    ..writeln()
    ..writeln('Registry _buildTesteadorRegistry() {')
    ..writeln('  final all = <CapturedTest>[];');
  for (final fe in fileEntries) {
    final stateVar = '${fe.importPrefix}_state';
    b
      ..writeln('  final $stateVar = CaptureState(')
      ..writeln("    packageName: '${_dartString(fe.manifest.packageName)}',")
      ..writeln(
        "    sourceUri: '${_dartString(fe.manifest.sourceRelativePath)}',",
      )
      ..writeln('  );')
      ..writeln(
        '  all.addAll(runCapture($stateVar, ${fe.importPrefix}.\$entry));',
      );
  }
  b
    ..writeln('  return Registry(all);')
    ..writeln('}')
    ..writeln()
    ..writeln(
      '/// Generated entry-point. See `TestInjector` static getters '
      'for per-test references.',
    )
    ..writeln('abstract final class TestInjector {')
    ..writeln('  static final Registry _registry = _buildTesteadorRegistry();')
    ..writeln();

  for (final t in testRefs) {
    b
      ..writeln(
        '  /// `${_dartDoc(t.captured.fqId)}` — '
        'tags: ${t.captured.tags.toList()..sort()}',
      )
      ..writeln('  static TestStep get ${t.identifier} =>')
      ..writeln(
        "      _registry.byFqId('${_dartString(t.captured.fqId)}');",
      )
      ..writeln();
  }

  b
    ..writeln('  /// Looks up tests by partial id (see [Registry.byName]).')
    ..writeln(
      '  static List<TestStep> byName(String spec) => _registry.byName(spec);',
    )
    ..writeln()
    ..writeln('  /// Looks up tests whose tags contain [tag].')
    ..writeln(
      '  static List<TestStep> byTags(String tag) => _registry.byTags(tag);',
    )
    ..writeln()
    ..writeln('  /// Looks up tests whose name matches [pattern].')
    ..writeln(
      '  static List<TestStep> byRegExp(Pattern pattern) => '
      '_registry.byRegExp(pattern);',
    )
    ..writeln('}');

  return b.toString();
}

String _dartString(String raw) =>
    raw.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

String _dartDoc(String raw) => raw.replaceAll('`', r'\`');

/// Serializes a single test entry. `coveredEndpoints` is omitted entirely when
/// `null` so that *un-annotated* (absent) and *annotated-but-empty* (`[]`)
/// survive the round-trip as distinct states.
Map<String, dynamic> _testToJson(DiscoveredTest t) {
  final json = <String, dynamic>{
    'name': t.name,
    'groupChain': t.groupChain,
    'tags': t.tags.toList(),
  };
  final covered = t.coveredEndpoints;
  if (covered != null) {
    json['coveredEndpoints'] = covered.map((e) => e.toJson()).toList();
  }
  return json;
}

/// Inverse of [_testToJson] for the `coveredEndpoints` field: an absent or
/// `null` value hydrates to `null` (cold-start); a present list (even empty)
/// hydrates to that list.
List<EndpointId>? _coveredEndpointsFromJson(Map<String, dynamic> test) {
  final raw = test['coveredEndpoints'];
  if (raw == null) return null;
  return (raw as List)
      .cast<Map<String, dynamic>>()
      .map(EndpointId.fromJson)
      .toList();
}
