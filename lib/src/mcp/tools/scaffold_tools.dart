import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:testeador/src/mcp/templates/_index.dart';
import 'package:testeador/src/mcp/tools/tools.dart';
import 'package:testeador/src/mcp/workspace.dart';

/// Registers the scaffolding tools: `scaffold_actor`, `scaffold_fixture`,
/// `scaffold_flow`, `scaffold_suite_runner`, `scaffold_dart_test_main`.
void registerScaffoldTools({
  required McpServer server,
  required WorkspaceConfig workspace,
}) {
  _registerScaffoldActor(server, workspace);
  _registerScaffoldFixture(server, workspace);
  _registerScaffoldFlow(server, workspace);
  _registerScaffoldSuiteRunner(server, workspace);
  _registerScaffoldDartTestMain(server, workspace);
}

/// Writes [content] to [path] unless the file exists. Honors [dryRun].
CallToolResult _emit({
  required WorkspaceConfig workspace,
  required String path,
  required String content,
  required bool dryRun,
}) {
  final abs = p.isAbsolute(path)
      ? path
      : p.normalize(p.join(workspace.root.path, path));
  if (dryRun) {
    return okResult({'path': abs, 'content': content, 'written': false});
  }
  final file = File(abs);
  if (file.existsSync()) {
    return errResult(
      'Refusing to overwrite existing file: $abs. '
      'Pass dry_run: true to preview, or choose a different output_path.',
    );
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  return okResult({'path': abs, 'content': content, 'written': true});
}

bool _dryRun(Map<String, Object?> args) => args['dry_run'] as bool? ?? false;

void _registerScaffoldActor(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'scaffold_actor',
    description:
        'Generates a testeador `Actor` subclass file from the canonical '
        'template. Returns the rendered content and writes it unless '
        '`dry_run: true` (or the target already exists, which is refused). '
        'Prefer this over hand-writing actors so the boilerplate stays in '
        'sync with the testeador API.',
    inputSchema: JsonSchema.object(
      properties: {
        'output_path': JsonSchema.string(),
        'class_name': JsonSchema.string(
          description: 'Dart class name, e.g. `FireshActor`.',
        ),
        'actor_name': JsonSchema.string(
          description: 'Human-readable name for logs, e.g. `Firesh`.',
        ),
        'base_url': JsonSchema.string(
          description: 'Optional base URL. Omit for a bare `Dio()`.',
        ),
        'dry_run': JsonSchema.boolean(defaultValue: false),
      },
      required: ['output_path', 'class_name', 'actor_name'],
    ),
    callback: (args, extra) async {
      try {
        final baseUrl = args['base_url'] as String?;
        final dioOptions = (baseUrl == null || baseUrl.isEmpty)
            ? ''
            : "BaseOptions(baseUrl: '$baseUrl')";
        final content = renderTemplate(templates['actor']!, {
          'class_name': args['class_name'] as String,
          'actor_name': args['actor_name'] as String,
          'dio_options': dioOptions,
        });
        return _emit(
          workspace: workspace,
          path: args['output_path'] as String,
          content: content,
          dryRun: _dryRun(args),
        );
      } on Object catch (e) {
        return errResult('scaffold_actor failed: $e');
      }
    },
  );
}

void _registerScaffoldFixture(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'scaffold_fixture',
    description:
        'Generates a testeador `Fixture<T>` subclass with `load()`/`dispose()` '
        'stubs from the canonical template. Returns the rendered content and '
        'writes it unless `dry_run: true`.',
    inputSchema: JsonSchema.object(
      properties: {
        'output_path': JsonSchema.string(),
        'class_name': JsonSchema.string(
          description: 'Dart class name, e.g. `SessionFixture`.',
        ),
        'context_type': JsonSchema.string(
          description: 'Concrete `T`, e.g. `SessionContext`.',
        ),
        'dry_run': JsonSchema.boolean(defaultValue: false),
      },
      required: ['output_path', 'class_name', 'context_type'],
    ),
    callback: (args, extra) async {
      try {
        final content = renderTemplate(templates['fixture']!, {
          'class_name': args['class_name'] as String,
          'context_type': args['context_type'] as String,
        });
        return _emit(
          workspace: workspace,
          path: args['output_path'] as String,
          content: content,
          dryRun: _dryRun(args),
        );
      } on Object catch (e) {
        return errResult('scaffold_fixture failed: $e');
      }
    },
  );
}

void _registerScaffoldFlow(McpServer server, WorkspaceConfig workspace) {
  server.registerTool(
    'scaffold_flow',
    description:
        'Generates a `TestFlowLasting` or `TestFlowTransient` factory '
        'function with a stubbed steps list. `kind` selects the flow type. '
        'Step names become `TestStep(name: ..., action: ...)` entries with '
        'TODO bodies. Returns the rendered content and writes it unless '
        '`dry_run: true`.',
    inputSchema: JsonSchema.object(
      properties: {
        'output_path': JsonSchema.string(),
        'flow_name': JsonSchema.string(
          description: 'Human-readable flow name.',
        ),
        'flow_function': JsonSchema.string(
          description: 'Builder function name, e.g. `buildSmokeJourneyFlow`.',
        ),
        'kind': JsonSchema.string(
          enumValues: ['lasting', 'transient'],
          defaultValue: 'lasting',
        ),
        'tags': JsonSchema.array(items: JsonSchema.string()),
        'description': JsonSchema.string(),
        'step_names': JsonSchema.array(items: JsonSchema.string()),
        'dry_run': JsonSchema.boolean(defaultValue: false),
      },
      required: ['output_path', 'flow_name', 'flow_function'],
    ),
    callback: (args, extra) async {
      try {
        final kind = (args['kind'] as String?) ?? 'lasting';
        final templateKey =
            kind == 'transient' ? 'flow_transient' : 'flow_lasting';
        final tags = (args['tags'] as List?)?.whereType<String>().toList() ??
            const <String>[];
        final stepNames =
            (args['step_names'] as List?)?.whereType<String>().toList() ??
                const <String>['TODO: first step'];
        final stepsBlock = stepNames
            .map(
              (s) => 'TestStep(\n'
                  "        name: '${_escape(s)}',\n"
                  '        action: () async {\n'
                  '          // TODO(testeador): implement this step.\n'
                  '        },\n'
                  '      ),',
            )
            .join('\n      ');
        final content = renderTemplate(templates[templateKey]!, {
          'flow_function': args['flow_function'] as String,
          'flow_name': _escape(args['flow_name'] as String),
          'flow_description':
              _escape((args['description'] as String?) ?? ''),
          'tags': tags.map((t) => "'${_escape(t)}'").join(', '),
          'actors_block':
              '// TODO(testeador): construct the actors used by this flow.',
          'steps_block': stepsBlock,
        });
        return _emit(
          workspace: workspace,
          path: args['output_path'] as String,
          content: content,
          dryRun: _dryRun(args),
        );
      } on Object catch (e) {
        return errResult('scaffold_flow failed: $e');
      }
    },
  );
}

void _registerScaffoldSuiteRunner(
  McpServer server,
  WorkspaceConfig workspace,
) {
  server.registerTool(
    'scaffold_suite_runner',
    description:
        'Generates a `bin/run_tests.dart` CLI entrypoint that wires actors '
        'and flow builders into `Testeador(...).run(args)`. Pass the actor '
        'and flow builder names; the tool emits the imports placeholders and '
        'instantiation skeleton. Returns content and writes unless '
        '`dry_run: true`.',
    inputSchema: JsonSchema.object(
      properties: {
        'output_path': JsonSchema.string(
          description: 'Defaults to `bin/run_tests.dart`.',
        ),
        'actor_imports': JsonSchema.array(items: JsonSchema.string()),
        'flow_imports': JsonSchema.array(items: JsonSchema.string()),
        'actor_factories': JsonSchema.array(items: JsonSchema.string()),
        'flow_builders': JsonSchema.array(items: JsonSchema.string()),
        'dry_run': JsonSchema.boolean(defaultValue: false),
      },
    ),
    callback: (args, extra) async {
      try {
        final actorImports =
            (args['actor_imports'] as List?)?.whereType<String>().toList() ??
                const <String>[];
        final flowImports =
            (args['flow_imports'] as List?)?.whereType<String>().toList() ??
                const <String>[];
        final actorFactories = (args['actor_factories'] as List?)
                ?.whereType<String>()
                .toList() ??
            const <String>[];
        final flowBuilders =
            (args['flow_builders'] as List?)?.whereType<String>().toList() ??
                const <String>['/* TODO: buildYourFlow() */'];

        final actorBlock = actorFactories.isEmpty
            ? '// TODO(testeador): instantiate actors here.'
            : actorFactories
                .asMap()
                .entries
                .map((e) => 'final actor${e.key} = ${e.value};')
                .join('\n  ');
        final actorsList = List.generate(
          actorFactories.length,
          (i) => 'actor$i',
        ).join(', ');

        final content = renderTemplate(templates['run_tests_cli']!, {
          'actor_imports': actorImports.map((i) => "import '$i';").join('\n'),
          'flow_imports': flowImports.map((i) => "import '$i';").join('\n'),
          'actor_block': actorBlock,
          'actors_list': actorsList,
          'flows_list': flowBuilders.map((b) => '$b,').join('\n      '),
        });
        return _emit(
          workspace: workspace,
          path: (args['output_path'] as String?) ?? 'bin/run_tests.dart',
          content: content,
          dryRun: _dryRun(args),
        );
      } on Object catch (e) {
        return errResult('scaffold_suite_runner failed: $e');
      }
    },
  );
}

void _registerScaffoldDartTestMain(
  McpServer server,
  WorkspaceConfig workspace,
) {
  server.registerTool(
    'scaffold_dart_test_main',
    description:
        'Generates a `test/contract_test.dart` file that registers flow '
        'builders with `Testeador(...).registerWithDartTest()` for `dart '
        'test` execution. Returns content and writes unless `dry_run: true`.',
    inputSchema: JsonSchema.object(
      properties: {
        'output_path': JsonSchema.string(
          description: 'Defaults to `test/contract_test.dart`.',
        ),
        'flow_imports': JsonSchema.array(items: JsonSchema.string()),
        'flow_builders': JsonSchema.array(items: JsonSchema.string()),
        'dry_run': JsonSchema.boolean(defaultValue: false),
      },
    ),
    callback: (args, extra) async {
      try {
        final flowImports =
            (args['flow_imports'] as List?)?.whereType<String>().toList() ??
                const <String>[];
        final flowBuilders =
            (args['flow_builders'] as List?)?.whereType<String>().toList() ??
                const <String>['/* TODO: buildYourFlow() */'];
        final content = renderTemplate(templates['contract_test']!, {
          'flow_imports': flowImports.map((i) => "import '$i';").join('\n'),
          'flows_list': flowBuilders.map((b) => '$b,').join('\n      '),
          'options_arg': '',
        });
        return _emit(
          workspace: workspace,
          path: (args['output_path'] as String?) ??
              'test/contract_test.dart',
          content: content,
          dryRun: _dryRun(args),
        );
      } on Object catch (e) {
        return errResult('scaffold_dart_test_main failed: $e');
      }
    },
  );
}

String _escape(String s) => s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
