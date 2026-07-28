import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// {@template evidence_file_system}
/// Thin, injectable seam over `dart:io` file operations used by the evidence
/// subsystem.
///
/// Exists so that disk-failure paths (a full disk, a permission error) can be
/// exercised in tests by substituting a throwing implementation — a capture
/// I/O failure must surface as a *harness* failure, clearly distinguishable
/// from an app failure.
/// {@endtemplate}
class EvidenceFileSystem {
  /// {@macro evidence_file_system}
  const EvidenceFileSystem();

  /// Writes [bytes] to [path], creating parent directories as needed.
  void writeBytes(String path, List<int> bytes) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }

  /// Atomically writes [content] to [path] (write to a temp file in the same
  /// directory, then rename over the destination).
  void writeStringAtomic(String path, String content) {
    final file = File(path)..parent.createSync(recursive: true);
    File('$path.tmp')
      ..writeAsStringSync(content)
      ..renameSync(file.path);
  }

  /// Reads [path] as bytes, or returns `null` if it does not exist.
  Uint8List? readBytesOrNull(String path) {
    final file = File(path);
    return file.existsSync() ? file.readAsBytesSync() : null;
  }

  /// Lists the file names (not full paths) directly inside [dir], or an
  /// empty list if the directory does not exist.
  List<String> listFileNames(String dir) {
    final directory = Directory(dir);
    if (!directory.existsSync()) return const [];
    return directory
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .toList();
  }

  /// Lists the names of the directories directly inside [dir], or an empty
  /// list if the directory does not exist.
  List<String> listSubdirNames(String dir) {
    final directory = Directory(dir);
    if (!directory.existsSync()) return const [];
    return directory
        .listSync()
        .whereType<Directory>()
        .map((d) => p.basename(d.path))
        .toList();
  }

  /// Deletes the file at [path] if it exists.
  void deleteIfExists(String path) {
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }

  /// Whether a file exists at [path].
  bool exists(String path) => File(path).existsSync();
}
