import 'dart:async';
import 'dart:convert';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:testeador/src/codegen/aggregator.dart';
import 'package:testeador/src/codegen/scanner.dart';
import 'package:testeador/src/codegen/transformer.dart';

/// Per-package builder factory referenced from `build.yaml`.
///
/// Runs in the host package and in any dependent package (`auto_apply:
/// dependents`). For every `test/**_test.dart` it emits a transformed copy
/// under `lib/src/_testeador/...` and a sibling manifest JSON.
Builder captureBuilderFactory(BuilderOptions options) => _CaptureBuilder();

/// Root-only builder factory. Collects every manifest emitted by
/// [captureBuilderFactory] across the package graph and emits a single
/// `lib/test_injector.g.dart` exposing the `TestInjector` API.
Builder aggregatorBuilderFactory(BuilderOptions options) =>
    _AggregatorBuilder();

class _CaptureBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
    'test/{{}}_test.dart': [
      'lib/src/_testeador/{{}}_test.testeador.dart',
      'lib/src/_testeador/{{}}_test.testeador.manifest.json',
    ],
  };

  @override
  Future<void> build(BuildStep step) async {
    final inputId = step.inputId;
    final source = await step.readAsString(inputId);
    final relPath = inputId.path;
    final packageName = inputId.package;

    final scan = scanTestSource(source, sourceLabel: relPath);
    scan.warnings.forEach(log.warning);
    if (scan.tests.isEmpty) {
      // Nothing to capture; emit empty outputs so build_runner doesn't
      // complain about missing declared assets.
      return;
    }

    final transformResult = transformTestSource(
      source: source,
      packageName: packageName,
      sourceRelativePath: relPath,
    );
    transformResult.warnings.forEach(log.warning);
    if (transformResult.skipped) return;

    final outputs = step.allowedOutputs.toList();
    final dartOut = outputs.firstWhere(
      (o) => o.path.endsWith('.testeador.dart'),
    );
    final manifestOut = outputs.firstWhere(
      (o) => o.path.endsWith('.manifest.json'),
    );

    await step.writeAsString(dartOut, transformResult.source);

    final transformedImport =
        'package:$packageName/${dartOut.path.substring('lib/'.length)}';
    final manifest = FileManifest(
      packageName: packageName,
      sourceRelativePath: relPath,
      transformedImport: transformedImport,
      entryPointName: transformResult.entryPointName,
      tests: scan.tests,
    );
    await step.writeAsString(manifestOut, jsonEncode(manifest.toJson()));
  }
}

class _AggregatorBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
    r'$package$': ['lib/test_injector.g.dart'],
  };

  @override
  Future<void> build(BuildStep step) async {
    final manifests = <FileManifest>[];
    final glob = Glob('lib/src/_testeador/**.testeador.manifest.json');
    await for (final assetId in step.findAssets(glob)) {
      final json = await step.readAsString(assetId);
      final m = FileManifest.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      manifests.add(m);
    }

    if (manifests.isEmpty) {
      log.info(
        'testeador: no captured tests found across the package graph; '
        'skipping test_injector.g.dart emission.',
      );
      return;
    }

    final result = generateTestInjector(manifests: manifests);
    result.warnings.forEach(log.warning);
    final outputId = AssetId(step.inputId.package, 'lib/test_injector.g.dart');
    await step.writeAsString(outputId, result.source);
  }
}
