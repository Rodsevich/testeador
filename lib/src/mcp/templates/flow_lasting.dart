// Raw strings keep template bodies safe to evolve: any future `${expr}`
// added to the snippet stays literal instead of being treated as Dart
// interpolation.
// ignore_for_file: unnecessary_raw_strings

/// Template for a `TestFlowLasting` factory.
///
/// Placeholders:
///   {{flow_function}}    Function name (e.g. `buildSmokeJourneyFlow`).
///   {{flow_name}}        Human-readable flow name.
///   {{flow_description}} Optional description (one short sentence).
///   {{tags}}             Comma-separated tag literals (e.g. `'smoke', 'e2e'`).
///   {{actors_block}}     Dart statements that build the actors used inside.
///   {{steps_block}}      Dart `TestStep(...)` entries, comma-separated.
const flowLastingTemplate = r'''
import 'package:testeador/testeador.dart';

/// {{flow_description}}
///
/// Tagged `lasting` because side effects intentionally persist after the flow.
/// Use this kind for write-path / seeding flows.
TestFlowLasting {{flow_function}}() {
  {{actors_block}}

  return TestFlowLasting(
    name: '{{flow_name}}',
    description: '{{flow_description}}',
    tags: { {{tags}} },
    steps: [
      {{steps_block}}
    ],
  );
}
''';
