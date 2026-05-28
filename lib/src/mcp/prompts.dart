import 'package:mcp_dart/mcp_dart.dart';

/// Registers reusable MCP prompts that guide an agent through common
/// testeador workflows.
void registerPrompts({required McpServer server}) {
  _registerScaffoldSuite(server);
  _registerDiagnoseFailure(server);
}

GetPromptResult _user(String text, {String? description}) {
  return GetPromptResult(
    description: description,
    messages: [
      PromptMessage(
        role: PromptMessageRole.user,
        content: TextContent(text: text),
      ),
    ],
  );
}

void _registerScaffoldSuite(McpServer server) {
  server.registerPrompt(
    'scaffold_suite',
    description:
        'Guide the creation of a full testeador contract-test suite from a '
        'project description: actors, fixtures, flows, and a CLI entrypoint.',
    argsSchema: {
      'project_description': const PromptArgumentDefinition(
        description: 'What the backend does and what to contract-test.',
      ),
      'actors': const PromptArgumentDefinition(
        description: 'Comma-separated actor names/roles (e.g. "Buyer, Seller").',
      ),
      'endpoints': const PromptArgumentDefinition(
        description: 'Comma-separated endpoints or features to cover.',
      ),
    },
    callback: (args, extra) async {
      final desc = args!['project_description'] as String;
      final actors = args['actors'] as String;
      final endpoints = args['endpoints'] as String;
      return _user(
        'Build a testeador contract-test suite.\n\n'
        '**Project:** $desc\n'
        '**Actors:** $actors\n'
        '**Endpoints / features:** $endpoints\n\n'
        'Steps:\n'
        '1. For each actor, call `scaffold_actor` (set base_url if known).\n'
        '2. If setup is needed (auth, seed data), call `scaffold_fixture`.\n'
        '3. For each cohesive journey, call `scaffold_flow` (kind: lasting '
        'for write-path, transient for read-only). Tag smoke flows '
        '`smoke` and exhaustive ones `regression`.\n'
        '4. Wire everything with `scaffold_suite_runner` (CLI) and/or '
        '`scaffold_dart_test_main` (dart test).\n'
        '5. Fill in the TODO step bodies with REAL HTTP calls — no mocks; '
        'testeador exists for integration contract testing.\n'
        '6. Validate with `inspect_suite`, then `dry_run_suite '
        '--include-tags smoke`, then a real `run_suite_cli`.',
        description: 'testeador suite scaffolding plan',
      );
    },
  );
}

void _registerDiagnoseFailure(McpServer server) {
  server.registerPrompt(
    'diagnose_failure',
    description:
        'Ingest the output of a failed testeador run and propose a root '
        'cause plus the next cURL command to reproduce it.',
    argsSchema: {
      'run_output': const PromptArgumentDefinition(
        description: 'stdout/stderr from a failing run_suite_cli call.',
      ),
    },
    callback: (args, extra) async {
      final output = args!['run_output'] as String;
      return _user(
        'A testeador run failed. Here is the output:\n\n'
        '```\n$output\n```\n\n'
        'Do the following:\n'
        '1. Identify which flow and which step failed (the `✗ FAILED` line).\n'
        '2. Read the per-actor cURL log block to see the exact request that '
        'preceded the failure.\n'
        '3. State the most likely root cause: a contract break (field rename, '
        'shape change, status code) vs. a test bug vs. backend downtime.\n'
        '4. Output the single cURL command to copy-paste and reproduce the '
        'failing request locally.\n'
        '5. Recommend the fix and whether it belongs to the backend or the '
        'frontend contract test.',
        description: 'testeador failure diagnosis',
      );
    },
  );
}
