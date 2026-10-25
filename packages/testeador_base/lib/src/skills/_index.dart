import 'package:testeador_base/src/skills/authoring_md.dart';
import 'package:testeador_base/src/skills/mirador_md.dart';
import 'package:testeador_base/src/skills/skill_md.dart';
import 'package:testeador_base/src/skills/verdicts_md.dart';

/// All skill files shipped with testeador, keyed by their install path
/// relative to `.claude/skills/testeador/`.
///
/// Used by `testeador skills install` to write skill files into a consumer
/// project. The keys are the exact relative paths the files must land at.
const Map<String, String> skillFiles = {
  'SKILL.md': skillMd,
  'references/authoring.md': authoringMd,
  'references/mirador.md': miradorMd,
  'references/verdicts.md': verdictsMd,
};
