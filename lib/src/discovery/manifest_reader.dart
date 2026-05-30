import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:testeador/src/codegen/aggregator.dart';

/// Reads every `*.testeador.manifest.json` reachable from [packageRoot].
///
/// The root package itself is always scanned. If a `.dart_tool/package_config.json`
/// is present, every package in it is also visited — that catches manifests
/// produced by the `capture` builder running in dependency packages
/// (`auto_apply: dependents`).
///
/// Returns the parsed [FileManifest]s in package-name → source-path order
/// (same comparator the aggregator uses internally), so any downstream
/// `IdentifierNamer` invocation produces identifiers that match the codegen
/// output verbatim.
Future<List<FileManifest>> readAllManifests(Directory packageRoot) async {
  final root = packageRoot.absolute;
  final seen = <String>{};
  final manifests = <FileManifest>[];

  Future<void> visit(Directory dir) async {
    final canonical = dir.absolute.path;
    if (!seen.add(canonical)) return;
    manifests.addAll(await _readFromPackageDir(dir));
  }

  await visit(root);

  final configFile = File(
    p.join(root.path, '.dart_tool', 'package_config.json'),
  );
  if (configFile.existsSync()) {
    final config =
        jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
    final packages = (config['packages'] as List).cast<Map<String, dynamic>>();
    for (final entry in packages) {
      final rootUri = entry['rootUri'] as String?;
      if (rootUri == null) continue;
      final abs = _resolveRootUri(rootUri, configFile.parent.path);
      if (abs == null) continue;
      final dir = Directory(abs);
      if (!dir.existsSync()) continue;
      await visit(dir);
    }
  }

  manifests.sort((a, b) {
    final byPkg = a.packageName.compareTo(b.packageName);
    if (byPkg != 0) return byPkg;
    return a.sourceRelativePath.compareTo(b.sourceRelativePath);
  });
  return manifests;
}

Future<List<FileManifest>> _readFromPackageDir(Directory pkgDir) async {
  final dir = Directory(p.join(pkgDir.path, 'lib', 'src', '_testeador'));
  if (!dir.existsSync()) return const [];
  final out = <FileManifest>[];
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.testeador.manifest.json')) continue;
    final body = await entity.readAsString();
    out.add(
      FileManifest.fromJson(jsonDecode(body) as Map<String, dynamic>),
    );
  }
  return out;
}

String? _resolveRootUri(String rootUri, String configDir) {
  if (rootUri.startsWith('file://')) {
    return Uri.parse(rootUri).toFilePath();
  }
  // package_config.json stores rootUri relative to the .dart_tool/ directory.
  return p.normalize(p.join(configDir, rootUri));
}
