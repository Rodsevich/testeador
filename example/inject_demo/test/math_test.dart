import 'package:inject_demo/math.dart';
import 'package:test/test.dart';

void main() {
  group('add', () {
    test('returns sum of two positives', () {
      expect(add(2, 3), equals(5));
    }, tags: ['smoke', 'pure']);

    test('is commutative', () {
      expect(add(7, 1), equals(add(1, 7)));
    }, tags: ['pure']);
  });

  group('multiply', () {
    test('returns product of two positives', () {
      expect(multiply(4, 5), equals(20));
    }, tags: ['smoke']);

    test('returns zero when any factor is zero', () {
      expect(multiply(0, 99), equals(0));
    });
  });
}
