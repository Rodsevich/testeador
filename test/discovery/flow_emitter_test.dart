import 'package:test/test.dart';
import 'package:testeador/src/codegen/aggregator.dart';
import 'package:testeador/src/codegen/scanner.dart';
import 'package:testeador/src/discovery/flow_emitter.dart';
import 'package:testeador/src/discovery/picker.dart';

void main() {
  group('emitInjectedFlow', () {
    test('renders a TestFlowLasting with TestInjector references', () {
      final catalog = _catalogWith([
        _test('round-trips', tags: {'codegen'}),
        _test('handles overflow', tags: {'codegen', 'edge'}),
      ]);
      final picked = catalog.entries;

      final source = emitInjectedFlow(
        InjectedFlowSpec(
          picked: picked,
          flowName: "Smoke 'roundtrip'",
          flowFunction: 'buildSmokeFlow',
          consumerPackageName: 'demo',
          description: 'Roundtrip smoke',
        ),
      );

      expect(
        source,
        contains("import 'package:demo/test_injector.g.dart';"),
      );
      expect(source, contains('TestFlowLasting buildSmokeFlow() {'));
      expect(source, contains('TestInjector.${picked.first.identifier}'));
      expect(source, contains('TestInjector.${picked.last.identifier}'));
      // Single-quote inside the flow name is escaped for the Dart literal.
      expect(source, contains(r"name: 'Smoke \'roundtrip\'',"));
      // Tag union from both tests (sorted) renders as a tight set literal.
      expect(source, contains("tags: {'codegen', 'edge'},"));
      expect(
        source,
        contains(
          'Testeador(flows: [buildSmokeFlow()]).registerWithDartTest();',
        ),
      );
    });

    test('renders an empty tag set without stray whitespace', () {
      final catalog = _catalogWith([_test('untagged')]);
      final source = emitInjectedFlow(
        InjectedFlowSpec(
          picked: catalog.entries,
          flowName: 'untagged',
          flowFunction: 'buildUntagged',
          consumerPackageName: 'demo',
        ),
      );
      expect(source, contains('tags: <String>{},'));
    });

    test('emits TestFlowTransient when kind is transient', () {
      final catalog = _catalogWith([_test('runs')]);
      final source = emitInjectedFlow(
        InjectedFlowSpec(
          picked: catalog.entries,
          flowName: 'transient',
          flowFunction: 'buildTransient',
          consumerPackageName: 'demo',
          kind: FlowKind.transient,
        ),
      );

      expect(source, contains('TestFlowTransient buildTransient() {'));
      expect(source, contains('return TestFlowTransient('));
    });

    test('respects overrideTags', () {
      final catalog = _catalogWith([
        _test('a', tags: {'auto-1', 'auto-2'}),
      ]);
      final source = emitInjectedFlow(
        InjectedFlowSpec(
          picked: catalog.entries,
          flowName: 'override',
          flowFunction: 'buildOverride',
          consumerPackageName: 'demo',
          overrideTags: {'manual'},
        ),
      );

      expect(source, contains("tags: {'manual'},"));
      expect(source, isNot(contains('auto-1')));
    });

    test('refuses to emit with an empty selection', () {
      expect(
        () => emitInjectedFlow(
          const InjectedFlowSpec(
            picked: [],
            flowName: 'x',
            flowFunction: 'x',
            consumerPackageName: 'demo',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

DiscoveredCatalog _catalogWith(List<DiscoveredTest> tests) {
  return DiscoveredCatalog.fromManifests([
    FileManifest(
      packageName: 'demo',
      sourceRelativePath: 'test/demo_test.dart',
      transformedImport:
          'package:demo/src/_testeador/demo_test.testeador.dart',
      entryPointName: r'_testeadorCapture$demo',
      tests: tests,
    ),
  ]);
}

DiscoveredTest _test(
  String name, {
  List<String> groupChain = const [],
  Set<String> tags = const {},
}) {
  return DiscoveredTest(name: name, groupChain: groupChain, tags: tags);
}
