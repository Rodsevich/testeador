import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:testeador/src/mcp/process_runner.dart';
import 'package:testeador/src/mcp/tools/tools.dart';
import 'package:testeador/src/mcp/workspace.dart';

/// Registers the `discover_tests` MCP tool.
///
/// The tool is a thin wrapper around the `testeador discover` subcommand
/// so the listing and scaffold logic has a single implementation.
void registerDiscoveryTools({
  required McpServer server,
  required WorkspaceConfig workspace,
}) {
  server.registerTool(
    'discover_tests',
    description:
        'Lists every test captured by `testeador` codegen in the workspace '
        '(reads the `lib/src/_testeador/*.testeador.manifest.json` artifacts '
        'produced by `dart run build_runner build`). When `pick_fqids` is '
        'omitted, returns the inventory as JSON so the agent can show the '
        'user what is available. When `pick_fqids` is provided, scaffolds a '
        '`dart test` entrypoint that wires those tests into a TestFlow via '
        '`TestInjector.<id>` references. Use `print: true` to receive the '
        'rendered snippet without writing a file, `dry_run: true` to preview '
        'the path that would be written. Backed by the shared CLI: '
        '`dart run testeador discover` — running that command manually is '
        'equivalent.',
    inputSchema: JsonSchema.object(
      properties: {
        'package_path': JsonSchema.string(
          description:
              'Working directory to run discovery in. Defaults to the '
              'resolved workspace root.',
        ),
        'filter_tags': JsonSchema.array(items: JsonSchema.string()),
        'filter_pattern': JsonSchema.string(
          description: 'Regex applied to each fqId during listing.',
        ),
        'filter_package': JsonSchema.string(
          description: 'Keep only tests captured from this Dart package.',
        ),
        'pick_fqids': JsonSchema.array(
          items: JsonSchema.string(),
          description: 'fqIds to inject. Provide to enter scaffold mode.',
        ),
        'output_path': JsonSchema.string(
          description: 'Default: test/picked_flow_test.dart.',
        ),
        'flow_name': JsonSchema.string(),
        'flow_function': JsonSchema.string(),
        'kind': JsonSchema.string(
          enumValues: ['lasting', 'transient'],
          defaultValue: 'lasting',
        ),
        'flow_tags': JsonSchema.array(items: JsonSchema.string()),
        'description': JsonSchema.string(),
        'dry_run': JsonSchema.boolean(defaultValue: false),
        'print': JsonSchema.boolean(defaultValue: false),
        'timeout_seconds': JsonSchema.integer(minimum: 1, defaultValue: 120),
      },
    ),
    callback: (args, extra) async {
      try {
        final cliArgs = _buildCliArgs(args);
        final cwd =
            (args['package_path'] as String?) ?? workspace.root.path;
        final timeout = Duration(
          seconds: (args['timeout_seconds'] as int?) ?? 120,
        );
        final result = await runProcess(
          executable: 'dart',
          arguments: ['run', 'testeador', 'discover', ...cliArgs],
          workingDirectory: cwd,
          timeout: timeout,
        );

        if (result.exitCode != 0) {
          return errResult(
            'testeador discover exited ${result.exitCode}.\n'
            'stdout:\n${result.stdout}\n'
            'stderr:\n${result.stderr}',
          );
        }

        final picks = (args['pick_fqids'] as List?)?.whereType<String>() ??
            const <String>[];
        if (picks.isEmpty) {
          final entries = _tryDecodeJsonList(result.stdout);
          return okResult({
            'mode': 'list',
            'entries': entries,
            'raw_stdout': entries == null ? result.stdout : null,
          });
        }

        if ((args['print'] as bool?) ?? false) {
          return okResult({
            'mode': 'scaffold_print',
            'content': result.stdout,
          });
        }

        return okResult({
          'mode': 'scaffold_write',
          'summary': result.stdout.trim(),
        });
      } on Object catch (e) {
        return errResult('discover_tests failed: $e');
      }
    },
  );
}

List<String> _buildCliArgs(Map<String, Object?> args) {
  final out = <String>[];
  final pkgPath = args['package_path'] as String?;
  if (pkgPath != null && pkgPath.isNotEmpty) {
    out
      ..add('--package')
      ..add(pkgPath);
  }
  for (final tag
      in (args['filter_tags'] as List?)?.whereType<String>() ??
          const <String>[]) {
    out
      ..add('--tag')
      ..add(tag);
  }
  final pattern = args['filter_pattern'] as String?;
  if (pattern != null && pattern.isNotEmpty) {
    out
      ..add('--pattern')
      ..add(pattern);
  }
  final pkgName = args['filter_package'] as String?;
  if (pkgName != null && pkgName.isNotEmpty) {
    out
      ..add('--package-name')
      ..add(pkgName);
  }

  final picks =
      (args['pick_fqids'] as List?)?.whereType<String>().toList() ??
      const <String>[];
  if (picks.isEmpty) {
    out.add('--json');
    return out;
  }

  for (final pick in picks) {
    out
      ..add('--pick')
      ..add(pick);
  }
  final outPath = args['output_path'] as String?;
  if (outPath != null && outPath.isNotEmpty) {
    out
      ..add('--out')
      ..add(outPath);
  }
  final flowName = args['flow_name'] as String?;
  if (flowName != null && flowName.isNotEmpty) {
    out
      ..add('--flow-name')
      ..add(flowName);
  }
  final flowFunction = args['flow_function'] as String?;
  if (flowFunction != null && flowFunction.isNotEmpty) {
    out
      ..add('--flow-function')
      ..add(flowFunction);
  }
  final kind = args['kind'] as String?;
  if (kind != null && kind.isNotEmpty) {
    out
      ..add('--kind')
      ..add(kind);
  }
  final flowTags =
      (args['flow_tags'] as List?)?.whereType<String>().toList() ??
      const <String>[];
  if (flowTags.isNotEmpty) {
    out
      ..add('--flow-tags')
      ..add(flowTags.join(','));
  }
  final description = args['description'] as String?;
  if (description != null && description.isNotEmpty) {
    out
      ..add('--description')
      ..add(description);
  }
  if ((args['dry_run'] as bool?) ?? false) out.add('--dry-run');
  if ((args['print'] as bool?) ?? false) out.add('--print');
  return out;
}

List<Object?>? _tryDecodeJsonList(String stdout) {
  final trimmed = stdout.trim();
  if (trimmed.isEmpty || !trimmed.startsWith('[')) return null;
  try {
    final decoded = jsonDecode(trimmed);
    return decoded is List ? decoded : null;
  } on FormatException {
    return null;
  }
}
