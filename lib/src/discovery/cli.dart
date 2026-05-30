import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:testeador/src/discovery/flow_emitter.dart';
import 'package:testeador/src/discovery/manifest_reader.dart';
import 'package:testeador/src/discovery/picker.dart';
import 'package:testeador/src/mcp/process_runner.dart';
import 'package:testeador/src/mcp/safe_write.dart';

/// Default destination of `--out` when picking interactively.
const defaultDiscoverOutPath = 'test/picked_flow_test.dart';

/// Default `name:` of the emitted [TestFlow](`package:testeador/testeador.dart`).
const _defaultFlowName = 'Picked tests';

/// Default builder-function identifier in the emitted file.
const _defaultFlowFunction = 'buildPickedFlow';

/// Entry-point for the `testeador discover` subcommand.
///
/// Returns the process exit code so the caller (the unified `testeador`
/// binary) can set `exitCode` without duplicating the printing logic.
/// Conventions follow the BSD sysexits.h family: `64` arg parse error,
/// `65` data/picks error, `66` no input/workspace, `73` cannot write.
Future<int> runDiscoverCli(List<String> args) async {
  final parser = buildDiscoverArgParser();
  final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(discoverUsage(parser));
    return 64;
  }

  if (results['help'] as bool) {
    stdout.writeln(discoverUsage(parser));
    return 0;
  }

  final root = _resolveRoot(results['package'] as String?);
  if (root == null) return 66;
  final consumerName = _resolveConsumerName(root);
  if (consumerName == null) {
    stderr.writeln(
      'testeador discover: could not resolve package name from '
      '${root.path}/pubspec.yaml.',
    );
    return 66;
  }

  if (results['build'] as bool) {
    final preflight = _preflightForBuildRunner(root);
    if (preflight != null) {
      stderr.writeln(preflight);
      return 78; // EX_CONFIG
    }
    final buildExit = await _runBuildRunner(root);
    if (buildExit != 0) return buildExit;
  }

  final manifests = await readAllManifests(root);
  if (manifests.isEmpty && !(results['build'] as bool)) {
    _warnIfStaleCache(root);
  }
  final catalog = DiscoveredCatalog.fromManifests(manifests);

  final filtered = _applyFilters(
    catalog,
    tags: results['tag'] as List<String>,
    pattern: results['pattern'] as String?,
    package: results['package-name'] as String?,
  );

  final picks = results['pick'] as List<String>;
  if (picks.isEmpty) {
    _printListing(filtered, asJson: results['json'] as bool);
    return 0;
  }

  final List<DiscoveredEntry> picked;
  try {
    picked = catalog.selectByFqIds(picks);
  } on UnknownFqIdException catch (e) {
    stderr.writeln(e.message);
    return 65;
  }

  final kind = (results['kind'] as String) == 'transient'
      ? FlowKind.transient
      : FlowKind.lasting;
  final overrideTagsArg = results['flow-tags'] as String?;
  final overrideTags = overrideTagsArg?.split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final spec = InjectedFlowSpec(
    picked: picked,
    flowName: (results['flow-name'] as String?) ?? _defaultFlowName,
    flowFunction:
        (results['flow-function'] as String?) ?? _defaultFlowFunction,
    consumerPackageName: consumerName,
    kind: kind,
    description: results['description'] as String?,
    headerComment: '// picked via: testeador discover ${_quote(args)}',
    overrideTags: overrideTags,
  );
  final content = emitInjectedFlow(spec);

  if (results['print'] as bool) {
    stdout.write(content);
    return 0;
  }

  final outPath = (results['out'] as String?) ?? defaultDiscoverOutPath;
  final write = safeWrite(
    workspaceRoot: root,
    path: outPath,
    content: content,
    dryRun: results['dry-run'] as bool,
  );
  if (!write.ok) {
    stderr.writeln(write.error);
    return 73;
  }
  final summary = '${picked.length} picked, kind: ${kind.name}';
  stdout.writeln(
    write.written
        ? 'Wrote ${write.absolutePath} ($summary).'
        : 'Would write ${write.absolutePath} ($summary).',
  );
  return 0;
}

/// Exposed so the unified entry-point can render help under
/// `testeador discover --help`.
ArgParser buildDiscoverArgParser() {
  return ArgParser()
    ..addOption(
      'package',
      help: 'Path of the consumer package to scan. Defaults to CWD.',
    )
    ..addMultiOption(
      'tag',
      help: 'Keep only tests whose tags contain this value. Repeatable.',
    )
    ..addOption(
      'pattern',
      help: 'Keep only tests whose fqId matches this regex.',
    )
    ..addOption(
      'package-name',
      help: 'Keep only tests captured from this Dart package.',
    )
    ..addFlag(
      'json',
      negatable: false,
      help: 'When listing, emit JSON instead of a human table.',
    )
    ..addMultiOption(
      'pick',
      help: 'fqId of a test to inject. Repeatable. Implies "emit flow" mode.',
    )
    ..addOption(
      'out',
      help: 'Destination path (default: $defaultDiscoverOutPath).',
    )
    ..addFlag(
      'print',
      negatable: false,
      help: 'Print the emitted flow to stdout instead of writing.',
    )
    ..addOption('flow-name', help: 'Flow display name.')
    ..addOption('flow-function', help: 'Builder function name.')
    ..addOption(
      'kind',
      allowed: ['lasting', 'transient'],
      defaultsTo: 'lasting',
      help: 'TestFlow subclass to emit.',
    )
    ..addOption(
      'flow-tags',
      help:
          'Comma-separated tag overrides for the flow itself. '
          "Defaults to the union of the picked tests' tags.",
    )
    ..addOption('description', help: 'Optional flow description.')
    ..addFlag(
      'dry-run',
      negatable: false,
      help: 'Compute the output path and content but do not write.',
    )
    ..addFlag(
      'build',
      defaultsTo: true,
      help:
          'Run `dart run build_runner build` before reading manifests so the '
          'listing is always fresh. Disable with `--no-build` when you have '
          'already built (e.g. from CI or an outer tool).',
    )
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');
}

/// Usage string for the discover subcommand.
String discoverUsage(ArgParser parser) =>
    'Usage: testeador discover [options]\n\n${parser.usage}';

Directory? _resolveRoot(String? explicit) {
  final candidate = explicit == null
      ? Directory.current
      : Directory(explicit);
  if (!candidate.existsSync()) {
    stderr.writeln(
      'testeador discover: --package ${candidate.path} not found.',
    );
    return null;
  }
  final pubspec = File('${candidate.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln(
      'testeador discover: no pubspec.yaml at ${candidate.path}. '
      'Run from inside the consumer package or pass --package.',
    );
    return null;
  }
  return candidate.absolute;
}

String? _resolveConsumerName(Directory root) {
  final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
  final match = RegExp(r'^name:\s*([^\s#]+)', multiLine: true).firstMatch(
    pubspec,
  );
  return match?.group(1);
}

List<DiscoveredEntry> _applyFilters(
  DiscoveredCatalog catalog, {
  required List<String> tags,
  String? pattern,
  String? package,
}) {
  var entries = List<DiscoveredEntry>.from(catalog.entries);
  for (final tag in tags) {
    entries = entries.where((e) => e.tags.contains(tag)).toList();
  }
  if (pattern != null) {
    final re = RegExp(pattern);
    entries = entries.where((e) => re.hasMatch(e.fqId)).toList();
  }
  if (package != null) {
    entries = entries.where((e) => e.packageName == package).toList();
  }
  return entries;
}

void _printListing(List<DiscoveredEntry> entries, {required bool asJson}) {
  if (asJson) {
    const encoder = JsonEncoder.withIndent('  ');
    stdout.writeln(encoder.convert([for (final e in entries) e.toJson()]));
    return;
  }
  if (entries.isEmpty) {
    stdout.writeln('No captured tests found.');
    return;
  }
  stdout.writeln(
    'Found ${entries.length} captured test'
    '${entries.length == 1 ? '' : 's'}:',
  );
  for (final e in entries) {
    final tags = e.tags.isEmpty
        ? ''
        : ' [${(e.tags.toList()..sort()).join(', ')}]';
    stdout
      ..writeln('  ${e.fqId}$tags')
      ..writeln('    identifier: TestInjector.${e.identifier}')
      ..writeln('    source:     ${e.packageName}/${e.sourceUri}');
  }
}

String _quote(List<String> args) =>
    args.map((a) => a.contains(' ') ? "'$a'" : a).join(' ');

/// Returns an actionable error message when the consumer package is not
/// equipped to run `build_runner build` against testeador's `capture`
/// builder, or `null` when the preflight passes.
///
/// The check is intentionally lightweight — we read `pubspec.yaml` as text
/// and grep for the right declarations. The build itself will surface any
/// deeper problem (e.g. version conflicts) with a richer error.
String? _preflightForBuildRunner(Directory root) {
  final pubspec = File('${root.path}/pubspec.yaml');
  if (!pubspec.existsSync()) {
    return 'testeador discover: no pubspec.yaml at ${root.path}. Run from '
        'inside a Dart package or pass --package.';
  }
  final body = pubspec.readAsStringSync();
  final hasTesteador = RegExp(
    r'^\s{2,4}testeador\s*:',
    multiLine: true,
  ).hasMatch(body);
  if (!hasTesteador) {
    return 'testeador discover: this package does not depend on '
        '`testeador`. Add it to pubspec.yaml (typically as a dev_dependency):\n'
        '\n'
        '  dev_dependencies:\n'
        '    testeador:\n'
        "      path: <path/to/testeador>   # or '^0.3.0' once published\n"
        '\n'
        'Then `dart pub get` and retry. Pass --no-build to skip this '
        'preflight if you only want to read already-emitted manifests.';
  }
  final hasBuildRunner = RegExp(
    r'^\s{2,4}build_runner\s*:',
    multiLine: true,
  ).hasMatch(body);
  if (!hasBuildRunner) {
    return 'testeador discover: this package does not have `build_runner` in '
        'dependencies/dev_dependencies, so the `testeador|capture` builder '
        'cannot run. Add it to pubspec.yaml:\n'
        '\n'
        '  dev_dependencies:\n'
        '    build_runner: ^2.4.0\n'
        '    build_test: ^3.5.0   # required if you also run `dart test` '
        'through build_runner\n'
        '\n'
        'Then `dart pub get` and retry. Pass --no-build to skip this '
        'preflight if you only want to read already-emitted manifests.';
  }
  final pkgConfig = File('${root.path}/.dart_tool/package_config.json');
  if (!pkgConfig.existsSync()) {
    return 'testeador discover: no .dart_tool/package_config.json — run '
        '`dart pub get` in ${root.path} first.';
  }
  return null;
}

/// Spawns `dart run build_runner build` in [root]. Streams the child's
/// stderr/stdout into our own so the user sees compile progress in real
/// time; returns the child's exit code.
Future<int> _runBuildRunner(Directory root) async {
  stderr.writeln(
    '[testeador discover] Running `dart run build_runner build` in '
    '${root.path} (pass --no-build to skip)…',
  );
  final result = await runProcess(
    executable: 'dart',
    arguments: const ['run', 'build_runner', 'build'],
    workingDirectory: root.path,
  );
  if (result.exitCode != 0) {
    stderr
      ..writeln(
        '[testeador discover] build_runner exited ${result.exitCode}.',
      )
      ..writeln('--- build_runner stdout ---')
      ..writeln(result.stdout)
      ..writeln('--- build_runner stderr ---')
      ..writeln(result.stderr);
  }
  return result.exitCode;
}

/// Emits a hint to stderr when no manifests were found under `lib/`. Two
/// common causes get explicit guidance:
///
/// 1. `dart run build_runner build` was never executed in this package.
/// 2. It WAS executed, but with the previous `build_to: cache` default, so
///    the manifests landed under `.dart_tool/build/generated/...` and the
///    reader (which only scans `lib/src/_testeador/`) does not see them.
void _warnIfStaleCache(Directory root) {
  final pkgConfig = File(
    '${root.path}/.dart_tool/package_config.json',
  );
  final cacheRoot = Directory(
    '${root.path}/.dart_tool/build/generated',
  );
  var staleFound = false;
  if (cacheRoot.existsSync()) {
    for (final pkgDir in cacheRoot.listSync().whereType<Directory>()) {
      final candidate = Directory(
        '${pkgDir.path}/lib/src/_testeador',
      );
      if (candidate.existsSync()) {
        final hits = candidate
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.testeador.manifest.json'))
            .toList();
        if (hits.isNotEmpty) {
          staleFound = true;
          stderr.writeln(
            '[testeador discover] Found stale manifest(s) under '
            '${candidate.path}. testeador now ships with '
            '`build_to: source`; re-run `dart run build_runner build` to '
            'move them under `lib/src/_testeador/` where the discover '
            'reader looks.',
          );
        }
      }
    }
  }
  if (staleFound) return;

  if (!pkgConfig.existsSync()) {
    stderr.writeln(
      '[testeador discover] No `.dart_tool/package_config.json` — run '
      '`dart pub get` first.',
    );
    return;
  }
  stderr.writeln(
    '[testeador discover] No captured tests yet. Run '
    '`dart run build_runner build` in this package (or in a dependency '
    'package) so the `testeador|capture` builder emits manifests under '
    '`lib/src/_testeador/`.',
  );
}
