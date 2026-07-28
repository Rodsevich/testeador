import 'package:test/test.dart';
import 'package:testeador_base/evidence.dart';

void main() {
  group('slugify', () {
    test('lowercases and keeps alphanumerics and underscores', () {
      expect(slugify('Carrito'), equals('carrito'));
      expect(slugify('paso_01'), equals('paso_01'));
    });

    test('replaces runs of invalid characters with a single underscore', () {
      expect(slugify('cupón aplicado'), equals('cup_n_aplicado'));
      expect(slugify(r'a/b\c'), equals('a_b_c'));
      expect(slugify('a  -  b'), equals('a_b'));
    });

    test('strips protocol characters ! and ~', () {
      expect(slugify('guardar!'), equals('guardar'));
      expect(slugify('año~2026'), equals('a_o_2026'));
      expect(slugify('save!!!now'), equals('save_now'));
    });

    test('trims leading and trailing underscores', () {
      expect(slugify('  hola  '), equals('hola'));
      expect(slugify('!!!hola!!!'), equals('hola'));
    });

    test('throws on input that slugifies to empty', () {
      expect(() => slugify('!!!'), throwsArgumentError);
      expect(() => slugify('~ ~'), throwsArgumentError);
    });
  });

  group('marksSuffix', () {
    test('produces N exclamation marks', () {
      expect(marksSuffix(0), isEmpty);
      expect(marksSuffix(1), equals('!'));
      expect(marksSuffix(5), equals('!!!!!'));
    });
  });

  group('file names', () {
    test('baseline has no order number and no markers', () {
      expect(
        baselineFileName(actor: 'comprador', slug: 'carrito'),
        equals('comprador-carrito.png'),
      );
    });

    test('capture carries zero-padded order and marker', () {
      expect(
        captureFileName(
          actor: 'comprador',
          order: 3,
          slug: 'carrito',
          marker: '!!',
        ),
        equals('comprador-03_carrito!!.png'),
      );
      expect(
        captureFileName(
          actor: 'comprador',
          order: 4,
          slug: 'cupon',
          marker: newMarker,
        ),
        equals('comprador-04_cupon~new.png'),
      );
    });

    test('diff triptych name mirrors the capture name', () {
      expect(
        diffFileName(
          actor: 'comprador',
          order: 3,
          slug: 'carrito',
          marker: '!!',
        ),
        equals('comprador-03_carrito!!.diff.png'),
      );
    });
  });

  group('ensureUniqueSlugs', () {
    test('passes when all slugs are unique', () {
      expect(
        () => ensureUniqueSlugs(['home', 'carrito', 'resumen']),
        returnsNormally,
      );
    });

    test('throws naming both colliding descriptions', () {
      expect(
        () => ensureUniqueSlugs(['Carrito!', 'carrito']),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            allOf(contains('Carrito!'), contains('carrito')),
          ),
        ),
      );
    });
  });
}
