import 'package:test/test.dart';
import 'package:testeador/src/codegen/aggregator.dart';
import 'package:testeador/src/codegen/scanner.dart';
import 'package:testeador/src/discovery/picker.dart';

void main() {
  group('DiscoveredCatalog', () {
    test('flattens manifests in package → source-path order', () {
      final catalog = DiscoveredCatalog.fromManifests([
        _manifest(
          pkg: 'beta',
          src: 'test/zeta_test.dart',
          tests: [_test('first')],
        ),
        _manifest(
          pkg: 'alpha',
          src: 'test/two_test.dart',
          tests: [_test('second')],
        ),
        _manifest(
          pkg: 'alpha',
          src: 'test/one_test.dart',
          tests: [_test('third')],
        ),
      ]);

      expect(
        catalog.entries.map((e) => e.fqId).toList(),
        [
          'alpha:third',
          'alpha:second',
          'beta:first',
        ],
      );
    });

    test('assigns the same identifier the aggregator would', () {
      final manifest = _manifest(
        pkg: 'pokebattle_serverpod_server',
        src: 'test/in_memory_store_test.dart',
        tests: [
          _test(
            'round-trips a registered user',
            groupChain: ['InMemoryStore'],
            tags: {'codegen'},
          ),
        ],
      );
      final catalog = DiscoveredCatalog.fromManifests([manifest]);
      expect(catalog.entries.single.identifier, 'roundTripsARegisteredUser');
    });

    test('disambiguates colliding names with group prefix', () {
      final catalog = DiscoveredCatalog.fromManifests([
        _manifest(
          pkg: 'p',
          src: 'test/a_test.dart',
          tests: [
            _test('runs', groupChain: ['fire']),
            _test('runs', groupChain: ['water']),
          ],
        ),
      ]);
      final ids = catalog.entries.map((e) => e.identifier).toList();
      expect(ids, ['runs', 'waterRuns']);
    });

    test('filterByTag returns only matching entries', () {
      final catalog = DiscoveredCatalog.fromManifests([
        _manifest(
          pkg: 'p',
          src: 'test/t.dart',
          tests: [
            _test('a', tags: {'smoke', 'fast'}),
            _test('b', tags: {'slow'}),
            _test('c', tags: {'smoke'}),
          ],
        ),
      ]);
      final smoke = catalog.filterByTag('smoke').map((e) => e.name).toList();
      expect(smoke, ['a', 'c']);
    });

    test('filterByPattern matches against fqId', () {
      final catalog = DiscoveredCatalog.fromManifests([
        _manifest(
          pkg: 'p',
          src: 'test/t.dart',
          tests: [
            _test('returns sum'),
            _test('returns difference'),
            _test('detects overflow'),
          ],
        ),
      ]);
      final matches = catalog
          .filterByPattern(RegExp('returns'))
          .map((e) => e.name)
          .toList();
      expect(matches, ['returns sum', 'returns difference']);
    });

    test(
      'selectByFqIds preserves caller order and throws on unknown ids',
      () {
        final catalog = DiscoveredCatalog.fromManifests([
          _manifest(
            pkg: 'p',
            src: 'test/t.dart',
            tests: [_test('a'), _test('b'), _test('c')],
          ),
        ]);

        final picked = catalog.selectByFqIds(['p:c', 'p:a']);
        expect(picked.map((e) => e.name), ['c', 'a']);

        expect(
          () => catalog.selectByFqIds(['p:a', 'p:nope']),
          throwsA(
            isA<UnknownFqIdException>().having(
              (e) => e.missing,
              'missing',
              ['p:nope'],
            ),
          ),
        );
      },
    );

    test('toJson exposes the fields the CLI consumes', () {
      final catalog = DiscoveredCatalog.fromManifests([
        _manifest(
          pkg: 'p',
          src: 'test/t.dart',
          tests: [
            _test('boots', groupChain: ['Server'], tags: {'boot'}),
          ],
        ),
      ]);
      expect(catalog.entries.single.toJson(), {
        'fqId': 'p:Server/boots',
        'identifier': 'boots',
        'package': 'p',
        'sourceUri': 'test/t.dart',
        'name': 'boots',
        'groupChain': ['Server'],
        'tags': ['boot'],
      });
    });
  });
}

FileManifest _manifest({
  required String pkg,
  required String src,
  required List<DiscoveredTest> tests,
}) {
  return FileManifest(
    packageName: pkg,
    sourceRelativePath: src,
    transformedImport: 'package:$pkg/src/_testeador/dummy.testeador.dart',
    entryPointName: r'_testeadorCapture$dummy',
    tests: tests,
  );
}

DiscoveredTest _test(
  String name, {
  List<String> groupChain = const [],
  Set<String> tags = const {},
}) {
  return DiscoveredTest(name: name, groupChain: groupChain, tags: tags);
}
