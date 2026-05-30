// Pipeline-level test for the testeador codegen: scanner → transformer →
// aggregator. The Builder wrappers in `builder_factories.dart` are pure
// shells around these three functions, so exercising the trio end-to-end
// gives us confidence the generated `test_injector.g.dart` is well-formed
// without spinning up `build_runner` (which is blocked in the example
// suites by a meta-package pin from `flutter_test`).

import 'package:test/test.dart';
import 'package:testeador/src/codegen/aggregator.dart';
import 'package:testeador/src/codegen/identifier_naming.dart';
import 'package:testeador/src/codegen/scanner.dart';
import 'package:testeador/src/codegen/transformer.dart';

void main() {
  group('scanner', () {
    test('extracts test() calls with their group chain and tags', () {
      const source = '''
import 'package:test/test.dart';

void main() {
  group('PokeApiClient', () {
    setUp(() {});
    test('fetchPokemon returns charizard', () {}, tags: ['smoke', 'fire']);
    test('fetchPokemon returns pikachu', () {}, tags: 'electric');
    group('errors', () {
      test('throws on 404', () {}, tags: {'errors'});
    });
  });
}
''';
      final result = scanTestSource(source);
      expect(result.warnings, isEmpty);
      expect(result.tests, hasLength(3));

      final charizard = result.tests[0];
      expect(charizard.name, 'fetchPokemon returns charizard');
      expect(charizard.groupChain, ['PokeApiClient']);
      expect(charizard.tags, {'smoke', 'fire'});

      final pikachu = result.tests[1];
      expect(pikachu.tags, {'electric'});

      final notFound = result.tests[2];
      expect(notFound.groupChain, ['PokeApiClient', 'errors']);
      expect(notFound.tags, {'errors'});
    });

    test('warns on non-literal test name and skips it', () {
      const source = '''
import 'package:test/test.dart';

void main() {
  final name = 'dynamic';
  test(name, () {});
}
''';
      final result = scanTestSource(source);
      expect(result.tests, isEmpty);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.single, contains('non-literal description'));
    });
  });

  group('transformer', () {
    test('rewrites package:test import and renames main()', () {
      const source = '''
import 'package:test/test.dart';

void main() {
  test('alpha', () {});
}
''';
      final result = transformTestSource(
        source: source,
        packageName: 'demo_pkg',
        sourceRelativePath: 'test/alpha_test.dart',
      );
      expect(result.skipped, isFalse);
      expect(result.source, contains("import 'package:testeador/captured.dart'"));
      expect(result.source, isNot(contains("import 'package:test/test.dart'")));
      expect(result.source, contains(result.entryPointName));
      expect(result.source, contains(r'const $entry ='));
    });

    test('skips files importing other test/ helpers', () {
      const source = '''
import 'package:test/test.dart';
import 'helpers/fixture.dart';

void main() {
  test('alpha', () {});
}
''';
      final result = transformTestSource(
        source: source,
        packageName: 'demo_pkg',
        sourceRelativePath: 'test/alpha_test.dart',
      );
      expect(result.skipped, isTrue);
      expect(result.warnings.single, contains('helpers/fixture.dart'));
    });

    test('rewrites ../lib/... relative imports to package: URIs', () {
      const source = '''
import 'package:test/test.dart';
import '../lib/foo.dart';

void main() {
  test('alpha', () {});
}
''';
      final result = transformTestSource(
        source: source,
        packageName: 'demo_pkg',
        sourceRelativePath: 'test/alpha_test.dart',
      );
      expect(result.skipped, isFalse);
      expect(result.source, contains("'package:demo_pkg/foo.dart'"));
    });
  });

  group('identifier_naming', () {
    test('camelCases names and folds Latin diacritics', () {
      expect(toLowerCamelCase('crea un usuario válido'),
          'creaUnUsuarioValido');
      expect(toLowerCamelCase('GET /users/:id'), 'getUsersId');
      expect(toLowerCamelCase('  spaced   words  '), 'spacedWords');
      expect(toLowerCamelCase(''), '');
    });
  });

  group('aggregator', () {
    test('emits a self-contained library with one getter per test', () {
      final manifests = [
        FileManifest(
          packageName: 'demo_pkg',
          sourceRelativePath: 'test/alpha_test.dart',
          transformedImport:
              'package:demo_pkg/src/_testeador/alpha_test.testeador.dart',
          entryPointName: r'_testeadorCapture$alpha_test_abc',
          tests: [
            DiscoveredTest(
              name: 'crea un usuario válido',
              groupChain: const ['Auth'],
              tags: {'smoke'},
            ),
            DiscoveredTest(
              name: 'rechaza email inválido',
              groupChain: const ['Auth'],
              tags: {'smoke', 'negative'},
            ),
          ],
        ),
      ];

      final result = generateTestInjector(manifests: manifests);
      expect(result.source, contains("import 'package:testeador/codegen.dart'"));
      expect(result.source, contains("import 'package:demo_pkg/src/_testeador/"));
      expect(result.source, contains('abstract final class TestInjector'));
      expect(result.source, contains('creaUnUsuarioValido'));
      expect(result.source, contains('rechazaEmailInvalido'));
      expect(result.source, contains("byFqId('demo_pkg:Auth/crea un usuario"));
      expect(result.source, contains('byName(String spec)'));
      expect(result.source, contains('byTags(String tag)'));
      expect(result.source, contains('byRegExp(Pattern pattern)'));
      expect(result.warnings, isEmpty);
    });

    test('disambiguates colliding test names across packages', () {
      final manifests = [
        for (final pkg in ['pkg_a', 'pkg_b'])
          FileManifest(
            packageName: pkg,
            sourceRelativePath: 'test/${pkg}_test.dart',
            transformedImport:
                'package:$pkg/src/_testeador/${pkg}_test.testeador.dart',
            entryPointName: '_testeadorCapture\$${pkg}_test_xx',
            tests: [
              DiscoveredTest(
                name: 'duplicado',
                groupChain: const [],
                tags: const {},
              ),
            ],
          ),
      ];

      final result = generateTestInjector(manifests: manifests);
      // First takes the natural id; second gets a package-prefixed fallback.
      expect(result.source, contains('TestStep get duplicado'));
      expect(result.source, contains('pkgBDuplicado'));
    });
  });
}
