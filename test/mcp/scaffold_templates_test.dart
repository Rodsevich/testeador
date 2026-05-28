import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:test/test.dart';
import 'package:testeador/src/mcp/templates/_index.dart';

/// Parses [source] and fails if it contains any *syntactic* error.
/// (Semantic errors like unresolved imports are not reported by parseString,
/// which is exactly what we want: templates are syntactically complete but
/// reference symbols that only resolve in a consumer project.)
void expectParses(String source, {required String label}) {
  final result = parseString(
    content: source,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  expect(
    result.errors,
    isEmpty,
    reason: 'Rendered "$label" template has syntax errors:\n'
        '${result.errors.join('\n')}\n\n--- source ---\n$source',
  );
}

void main() {
  group('renderTemplate', () {
    test('substitutes every provided placeholder', () {
      const tmpl = 'class {{class_name}} {} // {{actor_name}}';
      final out = renderTemplate(tmpl, {
        'class_name': 'Foo',
        'actor_name': 'bar',
      });
      expect(out, 'class Foo {} // bar');
    });

    test('leaves unknown placeholders intact', () {
      final out = renderTemplate('{{a}}-{{b}}', {'a': 'x'});
      expect(out, 'x-{{b}}');
    });
  });

  group('templates catalog', () {
    test('exposes all expected slugs', () {
      expect(
        templates.keys,
        containsAll(<String>[
          'actor',
          'fixture',
          'flow_lasting',
          'flow_transient',
          'run_tests_cli',
          'contract_test',
          'multidev_fleet',
        ]),
      );
    });
  });

  group('rendered templates are syntactically valid Dart', () {
    test('actor (with base url)', () {
      final out = renderTemplate(templates['actor']!, {
        'class_name': 'BuyerActor',
        'actor_name': 'Buyer',
        'dio_options': "BaseOptions(baseUrl: 'https://api.example.com')",
      });
      expectParses(out, label: 'actor');
    });

    test('actor (bare Dio)', () {
      final out = renderTemplate(templates['actor']!, {
        'class_name': 'BuyerActor',
        'actor_name': 'Buyer',
        'dio_options': '',
      });
      expectParses(out, label: 'actor-bare');
    });

    test('fixture', () {
      final out = renderTemplate(templates['fixture']!, {
        'class_name': 'SessionFixture',
        'context_type': 'SessionContext',
      });
      expectParses(out, label: 'fixture');
    });

    test('flow_lasting', () {
      final out = renderTemplate(templates['flow_lasting']!, {
        'flow_function': 'buildCheckoutFlow',
        'flow_name': 'Checkout journey',
        'flow_description': 'Buyer completes a checkout.',
        'tags': "'smoke', 'e2e'",
        'actors_block': 'final buyer = BuyerActor();',
        'steps_block': 'TestStep(\n'
            "        name: 'first step',\n"
            '        action: () async {},\n'
            '      ),',
      });
      expectParses(out, label: 'flow_lasting');
    });

    test('flow_transient', () {
      final out = renderTemplate(templates['flow_transient']!, {
        'flow_function': 'buildReadFlow',
        'flow_name': 'Read journey',
        'flow_description': 'Buyer reads data.',
        'tags': "'regression'",
        'actors_block': 'final buyer = BuyerActor();',
        'steps_block': 'TestStep(\n'
            "        name: 'first step',\n"
            '        action: () async {},\n'
            '      ),',
      });
      expectParses(out, label: 'flow_transient');
    });

    test('run_tests_cli', () {
      final out = renderTemplate(templates['run_tests_cli']!, {
        'actor_imports': "import 'actors.dart';",
        'flow_imports': "import 'flows/checkout.dart';",
        'actor_block': 'final actor0 = BuyerActor();',
        'actors_list': 'actor0',
        'flows_list': 'buildCheckoutFlow(),',
      });
      expectParses(out, label: 'run_tests_cli');
    });

    test('contract_test', () {
      final out = renderTemplate(templates['contract_test']!, {
        'flow_imports': "import 'flows/checkout.dart';",
        'flows_list': 'buildCheckoutFlow(),',
        'options_arg': '',
      });
      expectParses(out, label: 'contract_test');
    });

    test('multidev_fleet', () {
      final out = renderTemplate(templates['multidev_fleet']!, {
        'flow_function': 'buildBattleFlow',
        'flow_name': 'Battle journey',
        'tags': "'smoke'",
        'android_serial_a': 'emulator-5554',
        'android_serial_b': 'emulator-5556',
        'patrol_target': 'integration_test/battle_test.dart',
        'flutter_dir': './app',
      });
      expectParses(out, label: 'multidev_fleet');
    });
  });
}
