import 'package:test/test.dart';
import 'package:testeador/src/codegen/aggregator.dart';
import 'package:testeador/src/codegen/scanner.dart';
import 'package:testeador/src/contract/endpoint_id.dart';

void main() {
  group('FileManifest coveredEndpoints round-trip', () {
    FileManifest manifestWith(DiscoveredTest test) => FileManifest(
      packageName: 'pkg',
      sourceRelativePath: 'test/x_test.dart',
      transformedImport: 'package:pkg/src/_testeador/x_test.testeador.dart',
      entryPointName: r'_testeadorCapture$x',
      tests: [test],
    );

    DiscoveredTest only(FileManifest m) => m.tests.single;

    DiscoveredTest reparse(DiscoveredTest test) =>
        only(FileManifest.fromJson(manifestWith(test).toJson()));

    test('null coverage stays null and omits the JSON key', () {
      final test = DiscoveredTest(
        name: 't',
        groupChain: const [],
        tags: const {},
      );

      final json = manifestWith(test).toJson();
      final testJson = (json['tests'] as List).single as Map<String, dynamic>;
      expect(testJson.containsKey('coveredEndpoints'), isFalse);
      expect(reparse(test).coveredEndpoints, isNull);
    });

    test('empty coverage survives as an empty list (not null)', () {
      final test = DiscoveredTest(
        name: 't',
        groupChain: const [],
        tags: const {},
        coveredEndpoints: const [],
      );

      final round = reparse(test);
      expect(round.coveredEndpoints, isNotNull);
      expect(round.coveredEndpoints, isEmpty);
    });

    test('null and empty are distinct after a round-trip', () {
      final asNull = reparse(
        DiscoveredTest(name: 't', groupChain: const [], tags: const {}),
      ).coveredEndpoints;
      final asEmpty = reparse(
        DiscoveredTest(
          name: 't',
          groupChain: const [],
          tags: const {},
          coveredEndpoints: const [],
        ),
      ).coveredEndpoints;

      expect(asNull, isNull);
      expect(asEmpty, isEmpty);
      expect(asNull, isNot(asEmpty));
    });

    test('populated coverage round-trips by value', () {
      final test = DiscoveredTest(
        name: 't',
        groupChain: const [],
        tags: const {},
        coveredEndpoints: const [
          EndpointId(method: 'POST', templatedPath: '/players', service: 's'),
          EndpointId(
            method: 'GET',
            templatedPath: '/players/{id}',
            service: 's',
          ),
        ],
      );

      expect(reparse(test).coveredEndpoints, test.coveredEndpoints);
    });

    test('legacy manifest without the field hydrates to null', () {
      final legacy = {
        'packageName': 'pkg',
        'sourceRelativePath': 'test/x_test.dart',
        'transformedImport': 'package:pkg/src/_testeador/x_test.testeador.dart',
        'entryPointName': r'_testeadorCapture$x',
        'tests': [
          {'name': 't', 'groupChain': <String>[], 'tags': <String>[]},
        ],
      };

      final parsed = FileManifest.fromJson(legacy);
      expect(parsed.tests.single.coveredEndpoints, isNull);
    });
  });
}
