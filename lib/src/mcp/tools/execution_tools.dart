import 'dart:convert';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:testeador/src/mcp/curl_parser.dart';
import 'package:testeador/src/mcp/process_runner.dart';
import 'package:testeador/src/mcp/tools/tools.dart';
import 'package:testeador/src/mcp/workspace.dart';

const _defaultTimeoutSeconds = 600;

/// Registers `run_suite_cli`, `run_suite_dart_test`, `compile_suite_exe`.
void registerExecutionTools({
  required McpServer server,
  required WorkspaceConfig workspace,
}) {
  _registerRunSuiteCli(server, workspace);
  _registerRunSuiteDartTest(server, workspace);
  _registerCompileSuiteExe(server, workspace);
}

String _resolveAbs(WorkspaceConfig workspace, String path) {
  if (p.isAbsolute(path)) return path;
  return p.normalize(p.join(workspace.root.path, path));
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<String>().toList();
}

void _registerRunSuiteCli(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'run_suite_cli',
    description:
        'Runs a testeador suite as a standalone Dart binary (a `bin/*.dart` '
        'file that calls `Testeador(...).run(args)`). Use this for CI gates, '
        'smoke tests, and any case where the suite has its own `main()` '
        'entrypoint. Returns exit code, parsed flow pass/fail counts, full '
        'stdout/stderr, parsed cURL log per actor on failure, and total '
        'duration. Prefer `run_suite_dart_test` when the suite is registered '
        'via `registerWithDartTest()` inside a `test/*.dart` file. '
        'When `execute: false`, returns the command line without spawning.',
    inputSchema: JsonSchema.object(
      properties: {
        'suite_path': JsonSchema.string(
          description: 'Path to the `bin/*.dart` suite entrypoint.',
        ),
        'include_tags': JsonSchema.array(items: JsonSchema.string()),
        'exclude_tags': JsonSchema.array(items: JsonSchema.string()),
        'include_flows': JsonSchema.array(items: JsonSchema.string()),
        'exclude_flows': JsonSchema.array(items: JsonSchema.string()),
        'verbose': JsonSchema.boolean(defaultValue: false),
        'fail_fast': JsonSchema.boolean(defaultValue: true),
        'show_curls': JsonSchema.boolean(defaultValue: true),
        'show_stack_traces': JsonSchema.boolean(defaultValue: false),
        'working_directory': JsonSchema.string(
          description:
              'Optional working directory. Defaults to the workspace root.',
        ),
        'timeout_seconds': JsonSchema.integer(
          minimum: 1,
          defaultValue: _defaultTimeoutSeconds,
        ),
        'execute': JsonSchema.boolean(
          description:
              'When false, return the command without spawning. Default true.',
          defaultValue: true,
        ),
      },
      required: ['suite_path'],
    ),
    callback: (args, extra) async {
      try {
        final suitePath = _resolveAbs(
          workspace,
          args['suite_path'] as String,
        );
        if (!File(suitePath).existsSync()) {
          return errResult('suite_path does not exist: $suitePath');
        }
        final cwd = (args['working_directory'] as String?) ??
            workspace.root.path;
        final cliArgs = <String>[
          'run',
          suitePath,
          ..._tagFlags(args),
          if (args['verbose'] as bool? ?? false) '--verbose',
          if (args['fail_fast'] as bool? ?? true)
            '--fail-fast'
          else
            '--no-fail-fast',
          if (args['show_curls'] as bool? ?? true)
            '--show-curls'
          else
            '--no-show-curls',
          if (args['show_stack_traces'] as bool? ?? false)
            '--show-stack-traces',
        ];
        final execute = args['execute'] as bool? ?? true;
        if (!execute) {
          return okResult({
            'command': ['dart', ...cliArgs],
            'working_directory': cwd,
            'execute': false,
          });
        }
        final timeoutS = (args['timeout_seconds'] as num?)?.toInt() ??
            _defaultTimeoutSeconds;
        final result = await runProcess(
          executable: 'dart',
          arguments: cliArgs,
          workingDirectory: cwd,
          timeout: Duration(seconds: timeoutS),
        );
        final summary = parseRunSummary(result.stdout);
        final logs = parseCurlLogs('${result.stdout}\n${result.stderr}');
        return okResult({
          ...result.toJson(),
          if (summary != null) ...{
            'passed_count': summary.passed,
            'failed_count': summary.total - summary.passed,
            'total_count': summary.total,
          },
          'curl_logs': logs.map((l) => l.toJson()).toList(),
        });
      } on Object catch (e) {
        return errResult('run_suite_cli failed: $e');
      }
    },
  );
}

List<String> _tagFlags(Map<String, Object?> args) {
  String join(List<String> v) => v.join(',');
  final flags = <String>[];
  final inc = _stringList(args['include_tags']);
  final exc = _stringList(args['exclude_tags']);
  final incF = _stringList(args['include_flows']);
  final excF = _stringList(args['exclude_flows']);
  if (inc.isNotEmpty) flags.addAll(['--include-tags', join(inc)]);
  if (exc.isNotEmpty) flags.addAll(['--exclude-tags', join(exc)]);
  if (incF.isNotEmpty) flags.addAll(['--include-flows', join(incF)]);
  if (excF.isNotEmpty) flags.addAll(['--exclude-flows', join(excF)]);
  return flags;
}

void _registerRunSuiteDartTest(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'run_suite_dart_test',
    description:
        'Runs a testeador suite via `dart test` (a `test/*.dart` file that '
        'calls `Testeador(...).registerWithDartTest()`). Forwards name/tag '
        'filters to `dart test`. With `reporter: json` parses the event '
        'stream into per-test pass/fail breakdown. Use this when you want '
        'test-runner integration (IDE reporting, concurrency, JSON '
        'reporter); use `run_suite_cli` for compiled-binary CI flows.',
    inputSchema: JsonSchema.object(
      properties: {
        'suite_path': JsonSchema.string(
          description: 'Path to the `test/*.dart` suite file.',
        ),
        'name_pattern': JsonSchema.string(
          description: 'Forwarded as `--name`.',
        ),
        'tags': JsonSchema.array(items: JsonSchema.string()),
        'exclude_tags': JsonSchema.array(items: JsonSchema.string()),
        'concurrency': JsonSchema.integer(minimum: 1),
        'reporter': JsonSchema.string(
          enumValues: ['compact', 'expanded', 'json'],
          defaultValue: 'compact',
        ),
        'working_directory': JsonSchema.string(),
        'timeout_seconds': JsonSchema.integer(
          minimum: 1,
          defaultValue: _defaultTimeoutSeconds,
        ),
        'execute': JsonSchema.boolean(defaultValue: true),
      },
      required: ['suite_path'],
    ),
    callback: (args, extra) async {
      try {
        final suitePath = _resolveAbs(
          workspace,
          args['suite_path'] as String,
        );
        if (!File(suitePath).existsSync()) {
          return errResult('suite_path does not exist: $suitePath');
        }
        final cwd =
            (args['working_directory'] as String?) ?? workspace.root.path;
        final reporter = (args['reporter'] as String?) ?? 'compact';
        final namePattern = args['name_pattern'] as String?;
        final tags = _stringList(args['tags']);
        final excTags = _stringList(args['exclude_tags']);
        final concurrency = (args['concurrency'] as num?)?.toInt();

        final dartArgs = <String>[
          'test',
          suitePath,
          '--reporter',
          reporter,
          if (namePattern != null && namePattern.isNotEmpty) ...[
            '--name',
            namePattern,
          ],
          for (final t in tags) ...['--tags', t],
          for (final t in excTags) ...['--exclude-tags', t],
          if (concurrency != null) ...['--concurrency', '$concurrency'],
        ];

        final execute = args['execute'] as bool? ?? true;
        if (!execute) {
          return okResult({
            'command': ['dart', ...dartArgs],
            'working_directory': cwd,
            'execute': false,
          });
        }

        final timeoutS = (args['timeout_seconds'] as num?)?.toInt() ??
            _defaultTimeoutSeconds;
        final result = await runProcess(
          executable: 'dart',
          arguments: dartArgs,
          workingDirectory: cwd,
          timeout: Duration(seconds: timeoutS),
        );

        final summary = <String, dynamic>{};
        final failedTests = <Map<String, dynamic>>[];
        if (reporter == 'json') {
          _parseDartTestJson(result.stdout, summary, failedTests);
        }

        return okResult({
          ...result.toJson(),
          if (summary.isNotEmpty) 'summary': summary,
          if (failedTests.isNotEmpty) 'failed_tests': failedTests,
        });
      } on Object catch (e) {
        return errResult('run_suite_dart_test failed: $e');
      }
    },
  );
}

void _parseDartTestJson(
  String output,
  Map<String, dynamic> summary,
  List<Map<String, dynamic>> failedTests,
) {
  var passed = 0;
  var failed = 0;
  var skipped = 0;
  final tests = <int, Map<String, dynamic>>{};
  for (final line in const LineSplitter().convert(output)) {
    if (line.isEmpty || !line.startsWith('{')) continue;
    Object? decoded;
    try {
      decoded = json.decode(line);
    } on FormatException {
      continue;
    }
    if (decoded is! Map<String, dynamic>) continue;
    final type = decoded['type'];
    if (type == 'testStart') {
      final test = decoded['test'];
      if (test is Map<String, dynamic>) {
        tests[test['id'] as int? ?? -1] = {
          'name': test['name'],
          'group': (test['groupIDs'] as List?)?.lastOrNull,
        };
      }
    } else if (type == 'testDone') {
      final id = decoded['testID'] as int?;
      final result = decoded['result'] as String?;
      if (result == 'success') passed++;
      if (result == 'error' || result == 'failure') {
        failed++;
        final t = id != null ? tests[id] : null;
        failedTests.add({
          'test': t?['name'] ?? '<unknown>',
          'group': t?['group'],
          'result': result,
        });
      }
      if (result == 'skipped') skipped++;
    } else if (type == 'error') {
      final id = decoded['testID'] as int?;
      final t = id != null ? tests[id] : null;
      failedTests.add({
        'test': t?['name'] ?? '<unknown>',
        'error': decoded['error'],
        'stack_trace': decoded['stackTrace'],
      });
    }
  }
  summary
    ..['passed'] = passed
    ..['failed'] = failed
    ..['skipped'] = skipped;
}

void _registerCompileSuiteExe(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'compile_suite_exe',
    description:
        'Compiles a CLI suite (`bin/*.dart`) into a standalone native '
        'executable via `dart compile exe`. Useful for CI gates that should '
        'not depend on the Dart SDK at runtime. Returns the binary path, '
        'size in bytes, and compiler output. With `execute: false`, returns '
        'the command without compiling.',
    inputSchema: JsonSchema.object(
      properties: {
        'suite_path': JsonSchema.string(),
        'output_path': JsonSchema.string(
          description:
              'Optional output path. Defaults to `<dirname>/<basename>.exe`.',
        ),
        'working_directory': JsonSchema.string(),
        'execute': JsonSchema.boolean(defaultValue: true),
        'timeout_seconds': JsonSchema.integer(
          minimum: 1,
          defaultValue: _defaultTimeoutSeconds,
        ),
      },
      required: ['suite_path'],
    ),
    callback: (args, extra) async {
      try {
        final suitePath =
            _resolveAbs(workspace, args['suite_path'] as String);
        if (!File(suitePath).existsSync()) {
          return errResult('suite_path does not exist: $suitePath');
        }
        final defaultOut = p.join(
          p.dirname(suitePath),
          '${p.basenameWithoutExtension(suitePath)}.exe',
        );
        final outputPath = (args['output_path'] as String?) ?? defaultOut;
        final cwd =
            (args['working_directory'] as String?) ?? workspace.root.path;
        final dartArgs = ['compile', 'exe', suitePath, '-o', outputPath];

        final execute = args['execute'] as bool? ?? true;
        if (!execute) {
          return okResult({
            'command': ['dart', ...dartArgs],
            'output_path': outputPath,
            'working_directory': cwd,
            'execute': false,
          });
        }

        final timeoutS = (args['timeout_seconds'] as num?)?.toInt() ??
            _defaultTimeoutSeconds;
        final result = await runProcess(
          executable: 'dart',
          arguments: dartArgs,
          workingDirectory: cwd,
          timeout: Duration(seconds: timeoutS),
        );

        final size = File(outputPath).existsSync()
            ? File(outputPath).lengthSync()
            : 0;

        return okResult({
          ...result.toJson(),
          'output_path': outputPath,
          'size_bytes': size,
        });
      } on Object catch (e) {
        return errResult('compile_suite_exe failed: $e');
      }
    },
  );
}
