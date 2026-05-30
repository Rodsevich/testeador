import 'package:testeador/src/discovery/picker.dart';
import 'package:testeador/src/mcp/templates/_index.dart';

/// Distinguishes `TestFlowLasting` from `TestFlowTransient` when emitting.
enum FlowKind {
  /// Maps to `TestFlowLasting`. Default — side effects persist.
  lasting,

  /// Maps to `TestFlowTransient`. Marker only (no rollback yet).
  transient,
}

/// Parameters for [emitInjectedFlow]. Grouped so the CLI and the MCP tool
/// pass the same shape.
class InjectedFlowSpec {
  /// Builds a spec.
  const InjectedFlowSpec({
    required this.picked,
    required this.flowName,
    required this.flowFunction,
    required this.consumerPackageName,
    this.kind = FlowKind.lasting,
    this.description,
    this.headerComment = '',
    this.overrideTags,
  });

  /// Tests to inject as `TestStep`s, in declaration order.
  final List<DiscoveredEntry> picked;

  /// Human-readable name displayed by the runner.
  final String flowName;

  /// Builder function name (e.g. `buildPickedFlow`).
  final String flowFunction;

  /// Package that owns `lib/test_injector.g.dart`.
  ///
  /// Always the root package running the aggregator. Cross-package picks
  /// resolve through the root's generated registry.
  final String consumerPackageName;

  /// Flow class to emit.
  final FlowKind kind;

  /// Optional flow description.
  final String? description;

  /// Optional extra leading comment (multi-line OK). Useful for embedding the
  /// CLI invocation that produced the file.
  final String headerComment;

  /// When non-null, overrides the auto-computed union of test tags.
  final Set<String>? overrideTags;
}

/// Renders the contents of a `dart test` entrypoint that wires the picked
/// tests into a single `TestFlowLasting`/`TestFlowTransient` via
/// `TestInjector`.
String emitInjectedFlow(InjectedFlowSpec spec) {
  if (spec.picked.isEmpty) {
    throw ArgumentError('emitInjectedFlow: no tests selected.');
  }
  final tags =
      spec.overrideTags ?? {for (final e in spec.picked) ...e.tags};
  final sortedTags = tags.toList()..sort();
  final tagsLiteral = sortedTags.isEmpty
      ? '<String>{}'
      : "{${sortedTags.map((t) => "'${_escape(t)}'").join(', ')}}";
  final stepsBlock = spec.picked
      .map((e) => 'TestInjector.${e.identifier},')
      .join('\n      ');
  final templateKey = templates['injected_flow']!;
  final kindClass = spec.kind == FlowKind.transient
      ? 'TestFlowTransient'
      : 'TestFlowLasting';
  return renderTemplate(templateKey, {
    'header_comment': spec.headerComment,
    'consumer_package': spec.consumerPackageName,
    'flow_function': spec.flowFunction,
    'flow_kind_class': kindClass,
    'flow_name': _escape(spec.flowName),
    'flow_description': _escape(spec.description ?? ''),
    'tags_literal': tagsLiteral,
    'steps_block': stepsBlock,
  });
}

String _escape(String s) => s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
