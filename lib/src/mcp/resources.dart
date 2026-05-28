import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:testeador/src/mcp/templates/_index.dart';
import 'package:testeador/src/mcp/workspace.dart';

/// Registers MCP resources: scaffolding templates and project docs.
void registerResources({
  required McpServer server,
  required WorkspaceConfig workspace,
}) {
  _registerTemplates(server);
  _registerDocs(server, workspace);
}

ReadResourceResult _text(
  Uri uri,
  String text, {
  String mime = 'text/markdown',
}) {
  return ReadResourceResult(
    contents: [
      TextResourceContents(
        uri: uri.toString(),
        mimeType: mime,
        text: text,
      ),
    ],
  );
}

void _registerTemplates(McpServer server) {
  templates.forEach((slug, body) {
    server.registerResource(
      'Template: $slug',
      'testeador://templates/$slug',
      (
        mimeType: 'text/x-dart',
        description:
            'Scaffolding template for "$slug". Contains {{placeholder}} '
            'tokens; use the matching scaffold_* tool to render and write it.',
      ),
      (uri, extra) async => _text(uri, body, mime: 'text/x-dart'),
    );
  });
}

void _registerDocs(McpServer server, WorkspaceConfig workspace) {
  void docResource(String title, String uri, String relPath, String desc) {
    server.registerResource(
      title,
      uri,
      (mimeType: 'text/markdown', description: desc),
      (u, extra) async {
        final f = File(p.join(workspace.root.path, relPath));
        if (!f.existsSync()) {
          return _text(u, '$relPath not found under ${workspace.root.path}.');
        }
        return _text(u, await f.readAsString());
      },
    );
  }

  docResource(
    'testeador architecture',
    'testeador://docs/architecture',
    'docs/architecture.md',
    'Full technical specification of testeador.',
  );
  docResource(
    'testeador AGENTS guide',
    'testeador://docs/agents',
    'AGENTS.md',
    'Agent-agnostic entry point and critical rules.',
  );
  docResource(
    'testeador PRD',
    'testeador://docs/prd',
    'docs/PRD.md',
    'Product requirements: scope, goals, personas.',
  );
}
