import 'dart:io';

import 'package:test/test.dart';
import 'package:testeador/src/mcp/server.dart';
import 'package:testeador/src/mcp/workspace.dart';

void main() {
  group('buildServer', () {
    test('wires every tool/resource/prompt without throwing '
        '(multidev enabled)', () {
      final ws = WorkspaceConfig.resolve(
        environment: {'TESTEADOR_PROJECT_ROOT': Directory.current.path},
      );
      final server = buildServer(workspace: ws, enableMultidev: true);
      expect(server, isNotNull);
    });

    test('wires successfully with multidev disabled', () {
      final ws = WorkspaceConfig.resolve(
        environment: {'TESTEADOR_PROJECT_ROOT': Directory.current.path},
      );
      final server = buildServer(workspace: ws, enableMultidev: false);
      expect(server, isNotNull);
    });
  });

  group('WorkspaceConfig.resolve', () {
    test('honors TESTEADOR_PROJECT_ROOT when it exists', () {
      final ws = WorkspaceConfig.resolve(
        environment: {'TESTEADOR_PROJECT_ROOT': Directory.current.path},
      );
      expect(ws.root.path, Directory.current.absolute.path);
      expect(ws.isTesteadorRepo, isTrue);
    });

    test('falls back to CWD walk-up when env var is absent', () {
      final ws = WorkspaceConfig.resolve(environment: const {});
      // Running from the testeador repo, walk-up should find it.
      expect(ws.isTesteadorRepo, isTrue);
    });
  });
}
