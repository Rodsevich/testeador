import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:testeador/src/mcp/tools/execution_tools.dart';
import 'package:testeador/src/mcp/tools/introspection_tools.dart';
import 'package:testeador/src/mcp/tools/multidev_tools.dart';
import 'package:testeador/src/mcp/tools/scaffold_tools.dart';
import 'package:testeador/src/mcp/workspace.dart';

/// Wraps [data] into a successful `CallToolResult` carrying pretty JSON.
CallToolResult okResult(Object data) {
  final text =
      data is String ? data : const JsonEncoder.withIndent('  ').convert(data);
  return CallToolResult.fromContent([TextContent(text: text)]);
}

/// Wraps [message] into an error `CallToolResult`.
CallToolResult errResult(String message) =>
    CallToolResult(isError: true, content: [TextContent(text: message)]);

/// Registers every testeador MCP tool on [server].
///
/// Multidev tools are gated behind the `TESTEADOR_MCP_ENABLE_MULTIDEV` env
/// var (read by [WorkspaceConfig] at startup): they require `adb`/`xcrun` to
/// be on PATH and can fail noisily in headless CI containers if always on.
void registerTools({
  required McpServer server,
  required WorkspaceConfig workspace,
  required bool enableMultidev,
}) {
  registerIntrospectionTools(server: server, workspace: workspace);
  registerExecutionTools(server: server, workspace: workspace);
  registerScaffoldTools(server: server, workspace: workspace);
  if (enableMultidev) {
    registerMultidevTools(server: server, workspace: workspace);
  }
}
