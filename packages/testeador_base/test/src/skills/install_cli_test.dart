import 'dart:io';

import 'package:test/test.dart';
import 'package:testeador_base/src/skills/_index.dart';
import 'package:testeador_base/src/skills/install_cli.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('skills_install_test_');
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('creates all skill files in a fresh directory', () async {
    final code = await runSkillsInstallCli(['--project-root', tmp.path]);
    expect(code, 0);
    for (final key in skillFiles.keys) {
      final file = File('${tmp.path}/.claude/skills/testeador/$key');
      expect(await file.exists(), isTrue, reason: '$key was not created');
      expect(await file.readAsString(), skillFiles[key]);
    }
  });

  test('prints unchanged when content already matches', () async {
    // First install
    await runSkillsInstallCli(['--project-root', tmp.path]);
    // Second install — all unchanged
    final code = await runSkillsInstallCli(['--project-root', tmp.path]);
    expect(code, 0);
    // Verify files still exist with correct content
    for (final key in skillFiles.keys) {
      final file = File('${tmp.path}/.claude/skills/testeador/$key');
      expect(await file.readAsString(), skillFiles[key]);
    }
  });

  test('skips files with changed content without --force', () async {
    // Create a file with different content
    final skillFile = File('${tmp.path}/.claude/skills/testeador/SKILL.md');
    await skillFile.parent.create(recursive: true);
    await skillFile.writeAsString('old content');

    final code = await runSkillsInstallCli(['--project-root', tmp.path]);
    expect(code, 0);
    // File should not be overwritten
    expect(await skillFile.readAsString(), 'old content');
  });

  test('overwrites files with --force', () async {
    // Create a file with different content
    final skillFile = File('${tmp.path}/.claude/skills/testeador/SKILL.md');
    await skillFile.parent.create(recursive: true);
    await skillFile.writeAsString('old content');

    final code = await runSkillsInstallCli([
      '--project-root', tmp.path,
      '--force',
    ]);
    expect(code, 0);
    expect(await skillFile.readAsString(), skillFiles['SKILL.md']);
  });

  test('dry-run does not write files', () async {
    final code = await runSkillsInstallCli([
      '--project-root', tmp.path,
      '--dry-run',
    ]);
    expect(code, 0);
    final dir = Directory('${tmp.path}/.claude/skills/testeador');
    expect(await dir.exists(), isFalse);
  });

  test('--help returns 0', () async {
    final code = await runSkillsInstallCli(['--help']);
    expect(code, 0);
  });

  test('bad argument returns 64', () async {
    final code = await runSkillsInstallCli(['--unknown-flag']);
    expect(code, 64);
  });
}
