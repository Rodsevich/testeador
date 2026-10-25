import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:testeador_base/src/mcp/resources.dart';

void main() {
  group('resolveDocFile', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('docs_res_'));
    tearDown(() => tmp.deleteSync(recursive: true));

    File touch(String rel) => File(p.join(tmp.path, rel))
      ..createSync(recursive: true)
      ..writeAsStringSync(rel);

    test('reads package docs from the package root, not the consumer', () {
      touch('repo/packages/testeador_base/docs/architecture.md');
      final consumer = Directory(p.join(tmp.path, 'consumer'))..createSync();

      final f = resolveDocFile(
        'docs/architecture.md',
        packageRoot: Directory(
          p.join(tmp.path, 'repo/packages/testeador_base'),
        ),
        workspaceRoot: consumer,
      );

      expect(
        f?.readAsStringSync(),
        'repo/packages/testeador_base/docs/architecture.md',
      );
    });

    test('finds the monorepo AGENTS.md two levels above the package', () {
      touch('repo/AGENTS.md');

      final f = resolveDocFile(
        'AGENTS.md',
        packageRoot: Directory(
          p.join(tmp.path, 'repo/packages/testeador_base'),
        ),
        workspaceRoot: tmp,
      );

      expect(f?.readAsStringSync(), 'repo/AGENTS.md');
    });

    test(
      'falls back to the workspace root when the package root is unknown',
      () {
        touch('docs/PRD.md');

        final f = resolveDocFile(
          'docs/PRD.md',
          packageRoot: null,
          workspaceRoot: tmp,
        );

        expect(f?.readAsStringSync(), 'docs/PRD.md');
      },
    );

    test('returns null when no candidate exists', () {
      expect(
        resolveDocFile('docs/nope.md', packageRoot: tmp, workspaceRoot: tmp),
        isNull,
      );
    });
  });

  test('packageRoot resolves to this package under dart test', () {
    expect(
      File(
        p.join(testeadorBasePackageRoot()!.path, 'pubspec.yaml'),
      ).readAsStringSync(),
      contains('name: testeador_base'),
    );
  });
}
