import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('Pokemon App basic smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PokemonApp());
    expect(find.text('Pokemon Explorer'), findsOneWidget);
  });
}
