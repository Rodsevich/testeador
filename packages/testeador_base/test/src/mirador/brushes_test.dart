import 'package:test/test.dart';
import 'package:testeador_base/mirador.dart';

void main() {
  group('catálogo de pinceles', () {
    test('las teclas son únicas: ninguna sombra a otra', () {
      final keys = kBrushes.map((b) => b.key).toList();
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('los ids son únicos: el veredicto los usa como clave', () {
      final ids = kBrushes.map((b) => b.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('cubre los cuatro veredictos del contrato', () {
      final verdicts = kBrushes.map((b) => b.verdict).toSet();
      expect(
        verdicts,
        containsAll([
          Verdict.fixCode,
          Verdict.fixTest,
          Verdict.replaceBaseline,
        ]),
        reason:
            'sin un pincel por veredicto, ese veredicto es inalcanzable '
            'desde el panel',
      );
    });

    test('aprobar es el único que promueve baseline', () {
      final promoting = kBrushes
          .where((b) => b.verdict == Verdict.replaceBaseline)
          .map((b) => b.id);
      expect(promoting, equals(['aprobar']));
    });

    test('cada pincel declara su instrucción y su color', () {
      for (final b in kBrushes) {
        expect(b.instruction, isNotEmpty, reason: b.id);
        expect(b.color, matches(RegExp(r'^#[0-9a-f]{6}$')), reason: b.id);
      }
    });

    test('brushById encuentra y devuelve null en lo inexistente', () {
      expect(brushById('modificar')?.verdict, Verdict.fixCode);
      expect(brushById('no_existe'), isNull);
    });

    test('los wire de Verdict son los del schema', () {
      expect(
        Verdict.values.map((v) => v.wire),
        containsAll([
          'fix_code',
          'fix_test',
          'replace_baseline',
          'inconclusive',
        ]),
      );
    });
  });
}
