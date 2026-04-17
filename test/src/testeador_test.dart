// Not required for test files
// ignore_for_file: prefer_const_constructors
import 'package:test/test.dart';
import 'package:testeador/testeador.dart';

void main() {
  group('Testeador', () {
    test('can be instantiated', () {
      expect(Testeador(), isNotNull);
    });
  });
}
