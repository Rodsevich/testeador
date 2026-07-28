import 'dart:io';

import 'package:path/path.dart' as p;

/// Outcome of a [safeWrite] call.
///
/// Shared between the MCP scaffolding tools and the `testeador discover`
/// CLI so both honour the same "never overwrite" + `dry_run` contract.
class SafeWriteResult {
  /// Builds a successful result.
  SafeWriteResult.success({
    required this.absolutePath,
    required this.content,
    required this.written,
  }) : error = null;

  /// Builds a refused-write result (e.g. target already exists).
  SafeWriteResult.refused({
    required this.absolutePath,
    required this.content,
    required this.error,
  }) : written = false;

  /// Absolute path the write was targeted at.
  final String absolutePath;

  /// Content that was (or would have been) written.
  final String content;

  /// True when the file was actually written. False for dry runs and refusals.
  final bool written;

  /// Non-null when the write was refused. Carries a user-facing message.
  final String? error;

  /// `true` iff [error] is null.
  bool get ok => error == null;
}

/// Writes [content] to [path] unless the file already exists.
///
/// - [path] is resolved relative to [workspaceRoot] when it is not absolute.
/// - When [dryRun] is true, no file is touched; the result still reports the
///   absolute target path so callers can preview where it would land.
/// - Refuses to overwrite. Callers that need to replace a file must remove it
///   first.
SafeWriteResult safeWrite({
  required Directory workspaceRoot,
  required String path,
  required String content,
  required bool dryRun,
}) {
  final abs = p.isAbsolute(path)
      ? path
      : p.normalize(p.join(workspaceRoot.path, path));
  if (dryRun) {
    return SafeWriteResult.success(
      absolutePath: abs,
      content: content,
      written: false,
    );
  }
  final file = File(abs);
  if (file.existsSync()) {
    return SafeWriteResult.refused(
      absolutePath: abs,
      content: content,
      error:
          'Refusing to overwrite existing file: $abs. '
          'Pass dry_run: true to preview, or choose a different output path.',
    );
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  return SafeWriteResult.success(
    absolutePath: abs,
    content: content,
    written: true,
  );
}
