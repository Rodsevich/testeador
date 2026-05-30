import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

/// Result of [transformTestSource]: the rewritten source ready to be emitted
/// under `.dart_tool/build/generated/<pkg>/lib/...`, plus warnings the
/// builder should surface and a `bool skipped` flag.
class TransformResult {
  /// Builds a result.
  TransformResult({
    required this.source,
    required this.entryPointName,
    required this.warnings,
    required this.skipped,
  });

  /// Rewritten Dart source. Empty when [skipped] is true.
  final String source;

  /// Generated function name that captures the file's tests when invoked
  /// from the aggregator (`_testeadorCapture$<hash>`). Empty when skipped.
  final String entryPointName;

  /// Human-readable diagnostics produced by the transformer.
  final List<String> warnings;

  /// True when the file could not be transformed safely and should be
  /// excluded from the generated registry. v0 skips files importing other
  /// non-package test/ files because reproducing their imports is out of
  /// scope.
  final bool skipped;
}

/// Rewrites a `*_test.dart` source file so it can be replayed under
/// `captured.dart` to harvest its `test()` calls.
///
/// Transformations applied:
///
/// 1. Every `import 'package:test/test.dart'` (with or without combinators,
///    with or without prefix) is rewritten to
///    `import 'package:testeador/captured.dart'`.
/// 2. Relative imports that point up into `lib/` of [packageName]
///    (e.g. `'../lib/src/foo.dart'`) are rewritten to `package:<pkg>/...`.
/// 3. The top-level `void main()` function is renamed to
///    `_testeadorCapture$<hash>()`, and a top-level
///    `const \$entry = _testeadorCapture$<hash>;` is appended so the
///    aggregator can call it.
///
/// V0 limit: if the file imports another file under `test/` via a relative
/// import (e.g. `'fixtures/foo.dart'`), the file is skipped — reproducing
/// that import inside `.dart_tool/build/generated/...` requires recursive
/// processing that v1 will add.
TransformResult transformTestSource({
  required String source,
  required String packageName,
  required String sourceRelativePath,
}) {
  final parsed = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final unit = parsed.unit;
  final warnings = <String>[];
  final edits = <_Edit>[];

  final imports = unit.directives.whereType<ImportDirective>().toList();
  for (final imp in imports) {
    final raw = imp.uri.stringValue;
    if (raw == null) continue;
    final rewritten = _rewriteImport(raw, packageName);
    if (rewritten == null) {
      // Skip whole file: a relative test/ → test/ import we cannot reproduce.
      final reason =
          'skipped $sourceRelativePath: relative import "$raw" points to '
          'another test/ file; v0 does not yet copy sibling helpers.';
      return TransformResult(
        source: '',
        entryPointName: '',
        warnings: [reason],
        skipped: true,
      );
    }
    if (rewritten != raw) {
      edits.add(
        _Edit(
          start: imp.uri.offset + 1, // skip opening quote
          end: imp.uri.end - 1, // skip closing quote
          replacement: rewritten,
        ),
      );
    }
  }

  final mainFn = unit.declarations.whereType<FunctionDeclaration>().firstWhere(
    (d) => d.name.lexeme == 'main',
    orElse: () =>
        throw _TransformError('no top-level main() in $sourceRelativePath'),
  );

  final entryName =
      '_testeadorCapture\$${_safeId(sourceRelativePath)}';
  edits.add(
    _Edit(
      start: mainFn.name.offset,
      end: mainFn.name.end,
      replacement: entryName,
    ),
  );

  final rewritten = _applyEdits(source, edits);
  final withEntry =
      '$rewritten\n\n/// Aggregator entry-point for $sourceRelativePath.\n'
      'const \$entry = $entryName;\n';

  return TransformResult(
    source: withEntry,
    entryPointName: entryName,
    warnings: warnings,
    skipped: false,
  );
}

/// Returns the rewritten URI for [raw], or `null` to signal that the file
/// must be skipped (relative import pointing to another test/ file).
String? _rewriteImport(String raw, String packageName) {
  if (raw == 'package:test/test.dart') {
    return 'package:testeador/captured.dart';
  }
  if (raw.startsWith('package:test/')) {
    // Anything else from package:test (matchers, expect.dart) is re-exported
    // by captured.dart, so the safe rewrite is to point at the shim too.
    return 'package:testeador/captured.dart';
  }
  if (raw.startsWith('dart:') || raw.startsWith('package:')) return raw;
  // Relative import: figure out where it points.
  // The original lives at test/<relativeRest>; we resolve `raw` relative to
  // test/ to discover whether it ends up in lib/ (rewritable) or test/
  // (out-of-scope for v0).
  final normalized = p.posix.normalize(p.posix.join('test', raw));
  if (normalized.startsWith('lib/')) {
    final libPath = normalized.substring('lib/'.length);
    return 'package:$packageName/$libPath';
  }
  if (normalized.startsWith('test/')) {
    return null; // signal skip
  }
  // Path escapes both lib/ and test/ — package-private file or outside the
  // package; punt to v1.
  return null;
}

class _Edit {
  _Edit({required this.start, required this.end, required this.replacement});
  final int start;
  final int end;
  final String replacement;
}

String _applyEdits(String source, List<_Edit> edits) {
  edits.sort((a, b) => a.start.compareTo(b.start));
  final buffer = StringBuffer();
  var cursor = 0;
  for (final e in edits) {
    buffer
      ..write(source.substring(cursor, e.start))
      ..write(e.replacement);
    cursor = e.end;
  }
  buffer.write(source.substring(cursor));
  return buffer.toString();
}

String _safeId(String path) {
  final base = p.basenameWithoutExtension(path);
  final clean = base.replaceAll(RegExp('[^A-Za-z0-9_]'), '_');
  final hash = path.hashCode.toUnsigned(20).toRadixString(16);
  return '${clean}_$hash';
}

class _TransformError implements Exception {
  _TransformError(this.message);
  final String message;
  @override
  String toString() => 'TransformError: $message';
}
