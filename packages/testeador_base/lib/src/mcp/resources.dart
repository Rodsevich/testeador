import 'dart:io';
import 'dart:isolate';

import 'package:mcp_dart/mcp_dart.dart';
import 'package:path/path.dart' as p;
import 'package:testeador_base/src/mcp/templates/_index.dart';
import 'package:testeador_base/src/mcp/workspace.dart';

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

/// Root of the `testeador_base` package as resolved by the package config,
/// or `null` when unavailable (e.g. an AOT-compiled binary).
Directory? testeadorBasePackageRoot() {
  final lib = Isolate.resolvePackageUriSync(
    Uri.parse('package:testeador_base/'),
  );
  return lib == null ? null : Directory.fromUri(lib).parent;
}

/// Finds one of testeador's own docs. They ship with the package, not with the
/// consumer, so [packageRoot] and its two ancestors (the monorepo root, where
/// `AGENTS.md` lives) are tried before [workspaceRoot].
// ponytail: fixed 2-level walk-up matches the monorepo layout;
// revisit if docs move.
File? resolveDocFile(
  String relPath, {
  required Directory? packageRoot,
  required Directory workspaceRoot,
}) {
  final candidates = [
    if (packageRoot != null) ...[
      packageRoot,
      packageRoot.parent,
      packageRoot.parent.parent,
    ],
    workspaceRoot,
  ];
  for (final dir in candidates) {
    final f = File(p.join(dir.path, relPath));
    if (f.existsSync()) return f;
  }
  return null;
}

void _registerDocs(McpServer server, WorkspaceConfig workspace) {
  final packageRoot = testeadorBasePackageRoot();
  void docResource(String title, String uri, String relPath, String desc) {
    server.registerResource(
      title,
      uri,
      (mimeType: 'text/markdown', description: desc),
      (u, extra) async {
        final f = resolveDocFile(
          relPath,
          packageRoot: packageRoot,
          workspaceRoot: workspace.root,
        );
        if (f == null) return _text(u, '$relPath not found.');
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
