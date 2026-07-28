import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:testeador_base/src/evidence/evidence_file_system.dart';
import 'package:testeador_base/src/evidence/naming.dart';

/// {@template run_manifest}
/// The structural source of truth of an evidence run, written incrementally
/// as JSON after **every** step so a mid-flow crash never loses it.
///
/// One manifest exists per *scenario + actor* pair
/// (`runs/current/<scenario>/<actor>.manifest.json`), so two fixtures
/// exercising the same scenario with different actors can run under
/// `flutter test`'s default parallelism without racing each other.
///
/// All keys are English: this is a versioned public contract consumed by the
/// AI verdict agent (see `docs/verdict-schema.json` / `docs/verdict-agent.md`).
/// File names are for humans; nothing parses them back.
/// {@endtemplate}
final class RunManifest {
  /// {@macro run_manifest}
  ///
  /// Creating the manifest cleans this actor's previous artifacts inside
  /// [scenarioDir] (files prefixed `<actor>-` and the manifest itself) so
  /// stale markers from earlier runs never survive, then writes the initial
  /// manifest.
  /// The [actor] is slugified on entry so per-actor file scoping can never
  /// collide across actors (the `-` separator is not part of the slug
  /// alphabet) nor spoof drift markers (`!`, `~`).
  RunManifest({
    required String actor,
    required this.scenario,
    required this.scenarioDir,
    required String viewportPreset,
    required List<num> logicalSize,
    required num devicePixelRatio,
    required num capturePixelRatio,
    EvidenceFileSystem fileSystem = const EvidenceFileSystem(),
    Map<String, String>? environment,
  }) : actor = slugify(actor),
       _fs = fileSystem,
       _header = {
         'schemaVersion': schemaVersion,
         'scenario': scenario,
         'actor': slugify(actor),
         'environment': _environment(environment ?? Platform.environment),
         'viewport': {
           'preset': viewportPreset,
           'logicalSize': logicalSize,
           'devicePixelRatio': devicePixelRatio,
         },
         'capturePixelRatio': capturePixelRatio,
       } {
    _cleanPreviousRun();
    _write();
  }

  /// Version of the manifest JSON contract.
  static const int schemaVersion = 1;

  /// Scenario name (the flow name); also the artifact folder name.
  final String scenario;

  /// Actor slug (from the fixture context); prefixes every artifact of this
  /// run and names the manifest file.
  final String actor;

  /// Directory holding this scenario's run artifacts.
  final String scenarioDir;

  final EvidenceFileSystem _fs;
  final Map<String, Object?> _header;
  final List<Map<String, Object?>> _steps = [];

  /// Absolute path of the manifest file.
  String get path => p.join(scenarioDir, '$actor.manifest.json');

  /// Records a step and immediately rewrites the manifest atomically.
  ///
  /// [capture], [baseline] and the [diff] image are stored relative to the
  /// manifest location so artifacts remain resolvable when the run directory
  /// is moved (e.g. downloaded as a CI artifact).
  void recordStep({
    required int order,
    required String slug,
    required String description,
    required String status,
    String? intent,
    String? capture,
    String? baseline,
    ({double ratio, int marks, bool dimensionMismatch, String? image})? diff,
    Map<String, List<String>> attachments = const {},
    List<String> missingAttachments = const [],
    String? exception,
    String? origin,
  }) {
    _steps.add({
      'order': order,
      'slug': slug,
      'description': description,
      'status': status,
      'intent': ?intent,
      'capture': ?capture,
      'baseline': ?baseline,
      if (diff != null)
        'diff': {
          'ratio': diff.ratio,
          'marks': diff.marks,
          'dimensionMismatch': diff.dimensionMismatch,
          'image': ?diff.image,
        },
      if (attachments.isNotEmpty || missingAttachments.isNotEmpty)
        'attachments': {
          ...attachments,
          'missing': missingAttachments,
        },
      'exception': ?exception,
      'origin': ?origin,
    });
    _write();
  }

  /// Compares this actor's baselines in [baselineDir] against the steps
  /// recorded so far and stores the ones no step references — typically
  /// leftovers of a renamed or deleted step. Rewrites the manifest.
  void reconcileOrphans(
    String baselineDir, {
    Map<String, List<String>> unclaimedAttachments = const {},
  }) {
    final captured = _steps.map((s) => s['slug']).toSet();
    final orphans =
        _fs
            .listFileNames(baselineDir)
            .where(
              (name) => name.startsWith('$actor-') && name.endsWith('.png'),
            )
            .where((name) {
              final slug = name.substring(actor.length + 1, name.length - 4);
              return !captured.contains(slug);
            })
            .toList()
          ..sort();
    _header['orphanedBaselines'] = orphans;
    if (unclaimedAttachments.isNotEmpty) {
      _header['unclaimedAttachments'] = unclaimedAttachments;
    }
    _write();
  }

  void _cleanPreviousRun() {
    for (final name in _fs.listFileNames(scenarioDir)) {
      if (name.startsWith('$actor-') || name == '$actor.manifest.json') {
        _fs.deleteIfExists(p.join(scenarioDir, name));
      }
    }
    // Attachment folders (http/, logs/…) are one level deep: clean this
    // actor's files there too so stale evidence from a previous run can
    // never be re-attached as current.
    for (final dir in _fs.listSubdirNames(scenarioDir)) {
      final subdir = p.join(scenarioDir, dir);
      for (final name in _fs.listFileNames(subdir)) {
        if (name.startsWith('$actor-')) {
          _fs.deleteIfExists(p.join(subdir, name));
        }
      }
    }
  }

  void _write() {
    final json = const JsonEncoder.withIndent('  ').convert({
      ..._header,
      'steps': _steps,
    });
    _fs.writeStringAtomic(path, json);
  }

  static Map<String, Object?> _environment(Map<String, String> env) {
    String? flutterVersion;
    final flutterRoot = env['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final versionFile = File(p.join(flutterRoot, 'version'));
      if (versionFile.existsSync()) {
        flutterVersion = versionFile.readAsStringSync().trim();
      }
    }
    return {
      'flutter': ?flutterVersion,
      'platform': Platform.operatingSystem,
      'commit': ?env['GITHUB_SHA'],
    };
  }
}

/// Convenience for building the relative artifact references stored in the
/// manifest: paths relative to the manifest's own directory.
String manifestRelative({required String from, required String target}) =>
    p.relative(target, from: from);

/// Returns the run directory of a scenario:
/// `<baseDir>/runs/current/<scenario slug>`.
String scenarioRunDir({required String baseDir, required String scenario}) =>
    p.join(baseDir, 'runs', 'current', slugify(scenario));

/// Returns the baseline directory of a scenario:
/// `<baseDir>/baseline/<scenario slug>`.
String scenarioBaselineDir({
  required String baseDir,
  required String scenario,
}) => p.join(baseDir, 'baseline', slugify(scenario));
