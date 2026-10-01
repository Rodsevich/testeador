import 'package:test/test.dart';
import 'package:testeador_base/src/skills/_index.dart';

void main() {
  group('skillFiles', () {
    test('contains all four expected keys', () {
      expect(skillFiles.keys, containsAll([
        'SKILL.md',
        'references/authoring.md',
        'references/mirador.md',
        'references/verdicts.md',
      ]));
    });

    test('SKILL.md has frontmatter and feature loop', () {
      final content = skillFiles['SKILL.md']!;
      expect(content, contains('name: testeador'));
      expect(content, contains('## Feature loop'));
      expect(content, contains('## Hard rules'));
    });

    test('authoring.md has UiTestStep anatomy section', () {
      final content = skillFiles['references/authoring.md']!;
      expect(content, contains('## UiTestStep anatomy'));
      expect(content, contains('intent'));
      expect(content, contains('description'));
    });

    test('mirador.md has --propose JSON shape', () {
      final content = skillFiles['references/mirador.md']!;
      expect(content, contains('--propose'));
      expect(content, contains('replace_baseline'));
    });

    test('verdicts.md has verdict table', () {
      final content = skillFiles['references/verdicts.md']!;
      expect(content, contains('fix_code'));
      expect(content, contains('fix_test'));
      expect(content, contains('replace_baseline'));
      expect(content, contains('inconclusive'));
    });

    test('no skill file is empty', () {
      for (final entry in skillFiles.entries) {
        expect(entry.value, isNotEmpty, reason: '${entry.key} must not be empty');
      }
    });
  });
}
