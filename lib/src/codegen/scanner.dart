import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:testeador/src/contract/endpoint_id.dart';

/// Static descriptor of a `test()` call found in a `*_test.dart` source.
///
/// Holds only literal data resolvable from the unresolved AST. The captured
/// closure body is materialized later at codegen-run time by `captured.dart`;
/// the scanner just records *that there is* a test with this shape.
class DiscoveredTest {
  /// Builds a discovered-test descriptor.
  DiscoveredTest({
    required this.name,
    required this.groupChain,
    required this.tags,
    this.coveredEndpoints,
  });

  /// Literal first argument passed to `test('...')`.
  final String name;

  /// Enclosing `group()` chain, outermost first.
  final List<String> groupChain;

  /// Values from the `tags:` parameter, as accepted by `package:test`
  /// (`String`, `List<String>`, or `Set<String>` literals).
  final Set<String> tags;

  /// Backend endpoints this test covers, used as the baseline for the
  /// contract-coverage diff.
  ///
  /// The scanner cannot know this statically (Dio URLs are built at runtime),
  /// so it stays `null` here and is populated later by annotation/backfill.
  /// The distinction is load-bearing: `null` means *not annotated yet* (a
  /// cold-start, which downstream tooling warns about), whereas an empty list
  /// means *annotated and genuinely covers no endpoint*.
  final List<EndpointId>? coveredEndpoints;
}

/// Result of [scanTestSource]: the discovered tests plus any non-fatal
/// warnings (e.g. `test()` with a non-literal name).
class ScanResult {
  /// Builds a result.
  ScanResult(this.tests, this.warnings);

  /// Tests detected in the source, in declaration order.
  final List<DiscoveredTest> tests;

  /// Human-readable diagnostics emitted while scanning. Each entry should be
  /// surfaced by the builder so authors notice non-indexable `test()` calls.
  final List<String> warnings;
}

/// Parses [source] as a Dart compilation unit and returns every `test(...)`
/// call inside it, along with its enclosing `group()` chain and tags.
///
/// Uses unresolved AST parsing (no type resolution), mirroring the strategy
/// in `lib/src/mcp/suite_inspector.dart`. Tests whose first argument or
/// `tags:` argument are not literal strings are recorded as warnings and
/// skipped — they cannot be indexed reliably without full resolution.
ScanResult scanTestSource(String source, {String sourceLabel = '<unknown>'}) {
  final parsed = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = _TestCallVisitor(sourceLabel);
  parsed.unit.visitChildren(visitor);
  return ScanResult(visitor.tests, visitor.warnings);
}

class _TestCallVisitor extends RecursiveAstVisitor<void> {
  _TestCallVisitor(this._sourceLabel);

  final String _sourceLabel;
  final List<DiscoveredTest> tests = [];
  final List<String> warnings = [];
  final List<String> _groupStack = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'group') {
      _handleGroup(node);
    } else if (name == 'test') {
      _handleTest(node);
    } else {
      super.visitMethodInvocation(node);
    }
  }

  void _handleGroup(MethodInvocation node) {
    final args = node.argumentList.arguments;
    final groupName = args.isEmpty ? null : _literalString(args.first);
    if (groupName == null) {
      warnings.add(
        '$_sourceLabel: group() with non-literal description at offset '
        '${node.offset}; descendant tests will be indexed without this '
        'group name in their chain.',
      );
      super.visitMethodInvocation(node);
      return;
    }
    _groupStack.add(groupName);
    try {
      super.visitMethodInvocation(node);
    } finally {
      _groupStack.removeLast();
    }
  }

  void _handleTest(MethodInvocation node) {
    final args = node.argumentList.arguments;
    final testName = args.isEmpty ? null : _literalString(args.first);
    if (testName == null) {
      warnings.add(
        '$_sourceLabel: test() with non-literal description at offset '
        '${node.offset}; skipped.',
      );
      return;
    }
    final tags = _extractTags(node.argumentList);
    tests.add(
      DiscoveredTest(
        name: testName,
        groupChain: List.unmodifiable(_groupStack),
        tags: tags,
      ),
    );
    // Don't recurse into a test() body: nested test() calls are illegal in
    // package:test and would only add noise here.
  }

  String? _literalString(AstNode? expr) {
    if (expr is SimpleStringLiteral) return expr.value;
    if (expr is AdjacentStrings) {
      final sb = StringBuffer();
      for (final part in expr.strings) {
        if (part is SimpleStringLiteral) {
          sb.write(part.value);
        } else {
          return null;
        }
      }
      return sb.toString();
    }
    return null;
  }

  Set<String> _extractTags(ArgumentList args) {
    for (final a in args.arguments) {
      if (a is! NamedArgument) continue;
      if (a.name.lexeme != 'tags') continue;
      final expr = a.argumentExpression;
      final literal = _literalString(expr);
      if (literal != null) return {literal};
      if (expr is ListLiteral) return _stringsFromCollection(expr.elements);
      if (expr is SetOrMapLiteral) {
        return _stringsFromCollection(expr.elements);
      }
      warnings.add(
        '$_sourceLabel: tags: argument is not a literal String/List/Set at '
        'offset ${a.offset}; tags ignored.',
      );
      return const {};
    }
    return const {};
  }

  Set<String> _stringsFromCollection(Iterable<CollectionElement> elements) {
    final out = <String>{};
    for (final el in elements) {
      if (el is SimpleStringLiteral) out.add(el.value);
    }
    return out;
  }
}
