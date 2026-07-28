import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:testeador/testeador.dart';

void main() {
  setUpAll(setUpEvidence);

  testWidgets('setUpEvidence loads bundled Roboto without network access', (
    tester,
  ) async {
    // Rendering text with an explicit Roboto family must not throw and must
    // lay out with real glyph metrics (loaded via FontLoader from the
    // package's bundled assets — no HTTP involved).
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: Text(
            'Tipografía real',
            style: TextStyle(fontFamily: 'Roboto', fontSize: 24),
          ),
        ),
      ),
    );
    expect(find.text('Tipografía real'), findsOneWidget);
  });

  test('setUpEvidence is idempotent', () async {
    await setUpEvidence();
    await setUpEvidence();
  });
}
