import 'package:testeador/src/codegen/registry.dart';

/// Reserved Dart words that cannot be used verbatim as identifiers.
///
/// Source: https://dart.dev/language/keywords (the "reserved" column only;
/// built-ins like `dynamic` are legal as identifiers).
const _reservedWords = <String>{
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
  'default', 'do', 'else', 'enum', 'extends', 'false', 'final',
  'finally', 'for', 'if', 'in', 'is', 'new', 'null', 'rethrow',
  'return', 'super', 'switch', 'this', 'throw', 'true', 'try',
  'var', 'void', 'while', 'with',
};

/// Common Latin diacritic → ASCII fallback. Covers the marks that appear in
/// Spanish, Portuguese, French, German, Italian and Catalan test names.
const _diacriticFolding = <String, String>{
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o', 'ø': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c', 'ß': 'ss',
  'Á': 'A', 'À': 'A', 'Ä': 'A', 'Â': 'A', 'Ã': 'A', 'Å': 'A',
  'É': 'E', 'È': 'E', 'Ë': 'E', 'Ê': 'E',
  'Í': 'I', 'Ì': 'I', 'Ï': 'I', 'Î': 'I',
  'Ó': 'O', 'Ò': 'O', 'Ö': 'O', 'Ô': 'O', 'Õ': 'O', 'Ø': 'O',
  'Ú': 'U', 'Ù': 'U', 'Ü': 'U', 'Û': 'U',
  'Ñ': 'N', 'Ç': 'C',
};

/// Converts an arbitrary string to lowerCamelCase, dropping every character
/// that is not a Dart identifier character (A-Z a-z 0-9 underscore) and
/// folding common Latin diacritics to their ASCII base.
///
/// Examples:
/// - `'crea un usuario válido'` → `'creaUnUsuarioValido'`
/// - `'GET /users/:id'`          → `'getUsersId'`
/// - `'1 + 1 == 2'`              → `'112'`
/// - `''`                        → `''`
String toLowerCamelCase(String input) {
  final folded = _foldDiacritics(input);
  final tokens = folded
      .split(RegExp('[^A-Za-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toList();
  if (tokens.isEmpty) return '';
  final first = tokens.first.toLowerCase();
  final rest = tokens
      .skip(1)
      .map(
        (t) => t.substring(0, 1).toUpperCase() + t.substring(1).toLowerCase(),
      );
  return first + rest.join();
}

String _foldDiacritics(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final ch = String.fromCharCode(r);
    b.write(_diacriticFolding[ch] ?? ch);
  }
  return b.toString();
}

/// Ensures [base] is a legal Dart identifier — non-empty, not starting with a
/// digit, and not a reserved keyword. Falls back to `'test'` for empty input
/// and appends `$` for reserved-word collisions.
String _sanitizeIdentifier(String base) {
  if (base.isEmpty) return 'unnamed';
  final first = base.substring(0, 1);
  final safeStart = RegExp('[0-9]').hasMatch(first) ? 'test$base' : base;
  if (_reservedWords.contains(safeStart)) return '$safeStart\$';
  return safeStart;
}

/// Assigns unique Dart identifiers to a collection of [CapturedTest]s.
///
/// Resolution order on collision:
/// 1. Plain `lowerCamelCase` of the test name.
/// 2. Prefix with the innermost group name.
/// 3. Prefix with the package name.
/// 4. Suffix with a short hash of the `fqId` (always unique).
class IdentifierNamer {
  /// Map of `fqId` → assigned Dart identifier, in insertion order.
  final Map<String, String> assignments = {};

  final Set<String> _used = {};

  /// Registers [test] and returns its assigned identifier.
  String assign(CapturedTest test) {
    final base = toLowerCamelCase(test.name);
    final candidates = <String>[
      _sanitizeIdentifier(base),
      if (test.groupChain.isNotEmpty)
        _sanitizeIdentifier(
          '${toLowerCamelCase(test.groupChain.last)}'
          '${_capitalize(base)}',
        ),
      _sanitizeIdentifier(
        '${toLowerCamelCase(test.packageName)}${_capitalize(base)}',
      ),
    ];
    for (final c in candidates) {
      if (_used.add(c)) {
        assignments[test.fqId] = c;
        return c;
      }
    }
    // Hash fallback: always unique.
    final hash = test.fqId.hashCode.toUnsigned(20).toRadixString(16);
    final fallback = _sanitizeIdentifier('${base}_$hash');
    _used.add(fallback);
    assignments[test.fqId] = fallback;
    return fallback;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s.substring(0, 1).toUpperCase() + s.substring(1);
}
