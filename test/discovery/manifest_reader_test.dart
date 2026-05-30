import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:testeador/src/discovery/manifest_reader.dart';

void main() {
  group('readAllManifests', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('testeador_discover_test_');
    });

    tearDown(() async {
      await tmp.delete(recursive: true);
    });

    test('returns empty when the manifests directory is missing', () async {
      final manifests = await readAllManifests(tmp);
      expect(manifests, isEmpty);
    });

    test('reads every *.testeador.manifest.json in the root package',
        () async {
      _writeManifest(tmp, 'a_test', _sample('pkg_a', 'test/a_test.dart'));
      _writeManifest(tmp, 'b_test', _sample('pkg_a', 'test/b_test.dart'));

      final manifests = await readAllManifests(tmp);
      expect(
        manifests.map((m) => m.sourceRelativePath).toList(),
        containsAll(['test/a_test.dart', 'test/b_test.dart']),
      );
      expect(manifests, hasLength(2));
    });

    test('follows package_config.json into dependency packages', () async {
      _writeManifest(tmp, 'root_test', _sample('root', 'test/root_test.dart'));

      final depDir = Directory(p.join(tmp.path, 'deps', 'leaf'))
        ..createSync(recursive: true);
      _writeManifest(depDir, 'leaf_test', _sample('leaf', 'test/leaf_test.dart'));

      final configDir = Directory(p.join(tmp.path, '.dart_tool'))
        ..createSync();
      File(p.join(configDir.path, 'package_config.json'))
          .writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'root', 'rootUri': '..', 'packageUri': 'lib/'},
            {
              'name': 'leaf',
              'rootUri': '../deps/leaf',
              'packageUri': 'lib/',
            },
          ],
        }),
      );

      final manifests = await readAllManifests(tmp);
      expect(
        manifests.map((m) => m.packageName).toSet(),
        {'root', 'leaf'},
      );
    });

    test('sorts by package then source path', () async {
      _writeManifest(
        tmp,
        'z_test',
        _sample('zeta', 'test/z_test.dart'),
      );
      _writeManifest(
        tmp,
        'a_test',
        _sample('alpha', 'test/a_test.dart'),
      );

      final manifests = await readAllManifests(tmp);
      expect(
        manifests.map((m) => m.packageName).toList(),
        ['alpha', 'zeta'],
      );
    });
  });
}

Map<String, Object?> _sample(String pkg, String src) => {
      'packageName': pkg,
      'sourceRelativePath': src,
      'transformedImport':
          'package:$pkg/src/_testeador/${p.basenameWithoutExtension(src)}'
              '.testeador.dart',
      'entryPointName': r'_testeadorCapture$dummy',
      'tests': [
        {
          'name': 'sample',
          'groupChain': <String>[],
          'tags': <String>[],
        },
      ],
    };

void _writeManifest(Directory pkgRoot, String basename, Object payload) {
  final dir = Directory(p.join(pkgRoot.path, 'lib', 'src', '_testeador'))
    ..createSync(recursive: true);
  File(p.join(dir.path, '$basename.testeador.manifest.json'))
      .writeAsStringSync(jsonEncode(payload));
}
