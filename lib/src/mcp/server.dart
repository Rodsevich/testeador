import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:testeador/src/mcp/prompts.dart';
import 'package:testeador/src/mcp/resources.dart';
import 'package:testeador/src/mcp/suite_inspector.dart';
import 'package:testeador/src/mcp/tools/tools.dart';
import 'package:testeador/src/mcp/workspace.dart';

const _name = 'testeador-mcp';
const _version = '0.1.0';

/// Builds the testeador MCP server, fully wired and ready to connect to a
/// transport. Exposed separately so tests can drive it without a process.
McpServer buildServer({
  WorkspaceConfig? workspace,
  bool? enableMultidev,
}) {
  final ws = workspace ?? WorkspaceConfig.resolve();
  final multidev = enableMultidev ??
      (Platform.environment['TESTEADOR_MCP_ENABLE_MULTIDEV'] == '1');

  stderr
    ..writeln('[testeador_mcp] Project root: ${ws.root.path}')
    ..writeln('[testeador_mcp] Multidev tools: '
        '${multidev ? 'enabled' : 'disabled'}');

  final server = McpServer(
    const Implementation(name: _name, version: _version),
    options: const McpServerOptions(
      capabilities: ServerCapabilities(
        tools: ServerCapabilitiesTools(),
        resources: ServerCapabilitiesResources(),
        prompts: ServerCapabilitiesPrompts(),
      ),
    ),
  );

  registerTools(server: server, workspace: ws, enableMultidev: multidev);
  registerResources(server: server, workspace: ws);
  registerPrompts(server: server);

  return server;
}

/// Default entrypoint: builds the server and connects it via stdio.
Future<void> runServer({List<String> args = const []}) async {
  if (args.contains('--version')) {
    stdout.writeln('$_name $_version');
    return;
  }
  if (args.contains('--help') || args.contains('-h')) {
    _printHelp();
    return;
  }
  if (args.contains('--print-config')) {
    final ws = WorkspaceConfig.resolve();
    final suites = findSuites(ws.root);
    stdout
      ..writeln('project_root: ${ws.root.path}')
      ..writeln('is_testeador_repo: ${ws.isTesteadorRepo}')
      ..writeln('suites:');
    for (final s in suites) {
      stdout.writeln('  - ${s.path}');
    }
    return;
  }

  final server = buildServer();
  stderr.writeln('[testeador_mcp] Connecting stdio transport...');
  await server.connect(StdioServerTransport());
}

void _printHelp() {
  stdout.writeln('''
$_name $_version
Usage: testeador_mcp [flags]

Flags:
  --version         Print version and exit.
  --print-config    Print resolved project root + discovered suites.
  --help, -h        Show this help.

Environment:
  TESTEADOR_PROJECT_ROOT          Path to the project to operate on.
                                  Defaults to the nearest ancestor of CWD
                                  whose pubspec.yaml is or depends on
                                  testeador.
  TESTEADOR_MCP_ENABLE_MULTIDEV   Set to 1 to enable the multidev tools
                                  (list_devices, boot_fleet, snapshot_fleet,
                                  run_patrol_fleet). Requires adb/xcrun.
''');
}
