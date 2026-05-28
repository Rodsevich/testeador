// Raw strings keep template bodies safe to evolve: any future `${expr}`
// added to the snippet stays literal instead of being treated as Dart
// interpolation.
// ignore_for_file: unnecessary_raw_strings

/// Template for a `TestFlowTransient` factory.
///
/// `TestFlowTransient` is currently a marker type (no rollback implemented);
/// it behaves identically to `TestFlowLasting` at runtime but documents intent.
///
/// Placeholders match `flow_lasting.dart`.
const flowTransientTemplate = r'''
import 'package:testeador/testeador.dart';

/// {{flow_description}}
///
/// Tagged `transient`: side effects are not expected to persist. NOTE that
/// testeador's rollback is still TODO — this is intent only, not enforcement.
TestFlowTransient {{flow_function}}() {
  {{actors_block}}

  return TestFlowTransient(
    name: '{{flow_name}}',
    description: '{{flow_description}}',
    tags: { {{tags}} },
    steps: [
      {{steps_block}}
    ],
  );
}
''';
