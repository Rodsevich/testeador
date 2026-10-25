import 'dart:io';

import 'package:args/args.dart';
import 'package:testeador_base/src/skills/_index.dart';

const _skillsDir = '.claude/skills/testeador';

/// Installs testeador skill files into a consumer project's `.claude/skills/`
/// directory.
///
/// Returns an exit code: 0 on success, 64 on arg error, 73 on write failure.
Future<int> runSkillsInstallCli(List<String> args) async {
  final parser = ArgParser()
    ..addOption(
      'project-root',
      help: 'Root of the consumer project (default: current directory)',
    )
    ..addFlag('dry-run', help: 'Print what would change without writing')
    ..addFlag('force', help: 'Overwrite existing files that differ')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage');

  final ArgResults results;
  try {
    results = parser.parse(args);
  } on FormatException catch (e) {
    stderr
      ..writeln(e.message)
      ..writeln(_usage(parser));
    return 64;
  }

  if (results['help'] as bool) {
    stdout.writeln(_usage(parser));
    return 0;
  }

  final root = Directory(
    (results['project-root'] as String?) ?? Directory.current.path,
  );
  final dryRun = results['dry-run'] as bool;
  final force = results['force'] as bool;

  final targetDir = Directory('${root.path}/$_skillsDir');

  for (final entry in skillFiles.entries) {
    final file = File('${targetDir.path}/${entry.key}');
    final label = '$_skillsDir/${entry.key}';

    if (file.existsSync()) {
      final existing = await file.readAsString();
      if (existing == entry.value) {
        stdout.writeln('  unchanged: $label');
        continue;
      }
      if (!force) {
        stdout.writeln('  skip (use --force to overwrite): $label');
        continue;
      }
      if (dryRun) {
        stdout.writeln('  would update: $label');
        continue;
      }
      try {
        await file.writeAsString(entry.value);
        stdout.writeln('  updated: $label');
      } on IOException catch (e) {
        stderr.writeln('  error writing $label: $e');
        return 73;
      }
    } else {
      if (dryRun) {
        stdout.writeln('  would create: $label');
        continue;
      }
      try {
        await file.parent.create(recursive: true);
        await file.writeAsString(entry.value);
        stdout.writeln('  created: $label');
      } on IOException catch (e) {
        stderr.writeln('  error creating $label: $e');
        return 73;
      }
    }
  }

  if (dryRun) {
    stdout.writeln('\n(dry run — no files written)');
  }
  return 0;
}

String _usage(ArgParser parser) => '''
testeador skills install [options]

Writes .claude/skills/testeador/ into the target project.

${parser.usage}''';
