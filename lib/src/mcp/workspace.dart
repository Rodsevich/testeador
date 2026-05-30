import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves the project root the MCP server should operate on.
///
/// Lookup order:
///   1. `TESTEADOR_PROJECT_ROOT` environment variable.
///   2. The first ancestor of CWD whose `pubspec.yaml` declares testeador
///      (either *is* testeador, or depends on it).
///   3. The first ancestor of the running script that meets the same criterion.
///   4. CWD with a stderr warning so the server still starts.
class WorkspaceConfig {
  WorkspaceConfig._(this.root);

  /// Resolved project root directory.
  final Directory root;

  /// `evidence/` under the project root. Created on demand by snapshot tools.
  Directory get evidenceDir => Directory(p.join(root.path, 'evidence'));

  /// Repo-level `pubspec.yaml`.
  File get pubspec => File(p.join(root.path, 'pubspec.yaml'));

  /// `bin/` — where standalone CLI suites usually live.
  Directory get binDir => Directory(p.join(root.path, 'bin'));

  /// `test/` — where `registerWithDartTest()` suites usually live.
  Directory get testDir => Directory(p.join(root.path, 'test'));

  /// `example/` — only present in the testeador repo itself; useful for the
  /// MCP server's smoke tests when it runs inside testeador.
  Directory get exampleDir => Directory(p.join(root.path, 'example'));

  /// `true` when this is the testeador repo itself (used to show extra
  /// example-suite hints in tool descriptions).
  bool get isTesteadorRepo {
    if (!pubspec.existsSync()) return false;
    final body = pubspec.readAsStringSync();
    return RegExp(r'^name:\s*testeador\b', multiLine: true).hasMatch(body);
  }

  /// Resolves the project root from env vars, CWD walk-up, or script dir.
  // ignore: prefer_constructors_over_static_methods
  static WorkspaceConfig resolve({Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;

    final fromEnv = env['TESTEADOR_PROJECT_ROOT'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      final dir = Directory(fromEnv);
      if (dir.existsSync()) {
        return WorkspaceConfig._(dir.absolute);
      }
      stderr.writeln(
        '[testeador mcp] TESTEADOR_PROJECT_ROOT=$fromEnv does not exist. '
        'Will keep searching.',
      );
    }

    for (final start in [Directory.current, _scriptDir()]) {
      final found = _walkUp(start);
      if (found != null) return WorkspaceConfig._(found);
    }

    stderr.writeln(
      '[testeador mcp] Could not locate a project that uses testeador. '
      'Set TESTEADOR_PROJECT_ROOT or run from inside such a project. '
      'Falling back to CWD: ${Directory.current.path}',
    );
    return WorkspaceConfig._(Directory.current);
  }

  static Directory? _walkUp(Directory start) {
    Directory? cur = start.absolute;
    while (cur != null) {
      if (_looksLikeProject(cur)) return cur;
      final parent = cur.parent;
      if (parent.path == cur.path) return null;
      cur = parent;
    }
    return null;
  }

  static bool _looksLikeProject(Directory dir) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    final body = pubspec.readAsStringSync();
    // Either it IS testeador …
    if (RegExp(r'^name:\s*testeador\b', multiLine: true).hasMatch(body)) {
      return true;
    }
    // … or it depends on testeador.
    return RegExp(r'^\s{2}testeador:\s', multiLine: true).hasMatch(body);
  }

  static Directory _scriptDir() {
    final script = Platform.script.toFilePath();
    return Directory(p.dirname(script));
  }
}
