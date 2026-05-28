import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:testeador/src/mcp/suite_inspector.dart';
import 'package:testeador/src/mcp/tools/tools.dart';
import 'package:testeador/src/mcp/workspace.dart';
import 'package:testeador/src/test_flow.dart';
import 'package:testeador/src/testeador.dart' show filterFlows;
import 'package:testeador/src/testeador_options.dart';

/// Registers the introspection tools: `list_suites`, `inspect_suite`,
/// `list_tags`, `dry_run_suite`.
void registerIntrospectionTools({
  required McpServer server,
  required WorkspaceConfig workspace,
}) {
  _registerListSuites(server, workspace);
  _registerInspectSuite(server, workspace);
  _registerListTags(server, workspace);
  _registerDryRunSuite(server, workspace);
}

File _resolvePath(WorkspaceConfig workspace, String path) {
  if (p.isAbsolute(path)) return File(path);
  return File(p.normalize(p.join(workspace.root.path, path)));
}

void _registerListSuites(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'list_suites',
    description:
        'Scans the project for testeador suite entrypoints: `bin/*.dart` '
        'files that call `Testeador(...).run(args)` and `test/*.dart` files '
        'that call `registerWithDartTest()`. Also descends into `example/*/` '
        'for the testeador repo itself. Returns each suite path, its mode '
        '(cli/dart_test/unknown), flow count, and union of tags. Use this '
        'first when you do not know where the suites live.',
    inputSchema: JsonSchema.object(
      properties: {
        'project_root': JsonSchema.string(
          description:
              'Optional absolute path to scan. Defaults to the MCP server '
              'workspace (TESTEADOR_PROJECT_ROOT or CWD walk-up).',
        ),
      },
    ),
    callback: (args, extra) async {
      try {
        final rootPath = args['project_root'] as String?;
        final root = (rootPath == null || rootPath.isEmpty)
            ? workspace.root
            : Directory(rootPath);
        if (!root.existsSync()) {
          return errResult('project_root does not exist: ${root.path}');
        }
        final files = findSuites(root);
        final entries = <Map<String, dynamic>>[];
        for (final file in files) {
          final inspected = await inspectSuite(file);
          entries.add({
            'path': inspected.path,
            'mode': inspected.mode.name,
            'flow_count': inspected.flows.length,
            'tags': inspected.allTags.toList()..sort(),
          });
        }
        return okResult({
          'project_root': root.absolute.path,
          'count': entries.length,
          'suites': entries,
        });
      } on Object catch (e) {
        return errResult('list_suites failed: $e');
      }
    },
  );
}

void _registerInspectSuite(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'inspect_suite',
    description:
        'Parses a testeador suite file via the Dart analyzer and returns its '
        'structure: mode (cli vs dart_test), actors used, flows with their '
        'kind (lasting/transient), tags, descriptions, and step names. '
        'Read-only; does NOT execute anything. Use this to discover what '
        'tags/flows exist before calling `run_suite_cli` or `dry_run_suite`.',
    inputSchema: JsonSchema.object(
      properties: {
        'suite_path': JsonSchema.string(
          description:
              'Path to a suite file. Absolute, or relative to the workspace.',
        ),
      },
      required: ['suite_path'],
    ),
    callback: (args, extra) async {
      try {
        final path = args['suite_path'] as String;
        final file = _resolvePath(workspace, path);
        final inspected = await inspectSuite(file);
        return okResult(inspected.toJson());
      } on Object catch (e) {
        return errResult('inspect_suite failed: $e');
      }
    },
  );
}

void _registerListTags(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'list_tags',
    description:
        'Returns the sorted union of tags across every flow declared in a '
        'suite file. Quicker than `inspect_suite` when you only need tag '
        'completion for `--include-tags` / `--exclude-tags` filters.',
    inputSchema: JsonSchema.object(
      properties: {
        'suite_path': JsonSchema.string(description: 'Path to a suite file.'),
      },
      required: ['suite_path'],
    ),
    callback: (args, extra) async {
      try {
        final path = args['suite_path'] as String;
        final inspected = await inspectSuite(_resolvePath(workspace, path));
        return okResult({
          'suite_path': inspected.path,
          'tags': inspected.allTags.toList()..sort(),
        });
      } on Object catch (e) {
        return errResult('list_tags failed: $e');
      }
    },
  );
}

void _registerDryRunSuite(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'dry_run_suite',
    description:
        'Computes which flows a `run_suite_cli` invocation WOULD execute '
        'given the same include/exclude tag and flow filters, without '
        'spawning any process. Returns `would_run_flows` and '
        '`would_skip_flows` (each with skip reason). Use to validate filters '
        'before a long run, or to preview what `--include-tags smoke` will '
        'actually cover.',
    inputSchema: JsonSchema.object(
      properties: {
        'suite_path': JsonSchema.string(description: 'Path to a suite file.'),
        'include_tags': JsonSchema.array(items: JsonSchema.string()),
        'exclude_tags': JsonSchema.array(items: JsonSchema.string()),
        'include_flows': JsonSchema.array(items: JsonSchema.string()),
        'exclude_flows': JsonSchema.array(items: JsonSchema.string()),
      },
      required: ['suite_path'],
    ),
    callback: (args, extra) async {
      try {
        final path = args['suite_path'] as String;
        final inspected = await inspectSuite(_resolvePath(workspace, path));
        final options = TesteadorOptions(
          includeTags: _stringSet(args['include_tags']),
          excludeTags: _stringSet(args['exclude_tags']),
          includeFlows: _stringSet(args['include_flows']),
          excludeFlows: _stringSet(args['exclude_flows']),
        );
        final pseudoFlows = inspected.flows
            .map(
              (f) => f.kind == FlowKind.lasting
                  ? TestFlowLasting(
                      name: f.name,
                      steps: const [],
                      tags: f.tags.toSet(),
                    )
                  : TestFlowTransient(
                      name: f.name,
                      steps: const [],
                      tags: f.tags.toSet(),
                    ),
            )
            .toList();
        final kept = filterFlows(pseudoFlows, options)
            .map((f) => f.name)
            .toSet();
        final wouldRun = inspected.flows
            .where((f) => kept.contains(f.name))
            .map((f) => {'name': f.name, 'tags': f.tags})
            .toList();
        final wouldSkip = <Map<String, dynamic>>[];
        for (final f in inspected.flows) {
          if (kept.contains(f.name)) continue;
          wouldSkip.add({
            'name': f.name,
            'tags': f.tags,
            'reason': _skipReason(f, options),
          });
        }
        return okResult({
          'suite_path': inspected.path,
          'filters': {
            'include_tags': options.includeTags.toList(),
            'exclude_tags': options.excludeTags.toList(),
            'include_flows': options.includeFlows.toList(),
            'exclude_flows': options.excludeFlows.toList(),
          },
          'would_run_flows': wouldRun,
          'would_skip_flows': wouldSkip,
        });
      } on Object catch (e) {
        return errResult('dry_run_suite failed: $e');
      }
    },
  );
}

Set<String> _stringSet(Object? raw) {
  if (raw is! List) return const {};
  return raw.whereType<String>().toSet();
}

String _skipReason(InspectedFlow f, TesteadorOptions opts) {
  if (opts.includeFlows.isNotEmpty && !opts.includeFlows.contains(f.name)) {
    return 'not in include_flows';
  }
  if (opts.excludeFlows.contains(f.name)) return 'matched exclude_flows';
  if (opts.includeTags.isNotEmpty &&
      !f.tags.any(opts.includeTags.contains)) {
    return 'no tag in include_tags';
  }
  if (f.tags.any(opts.excludeTags.contains)) return 'tag in exclude_tags';
  return 'skipped';
}
