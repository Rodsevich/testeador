// Raw strings keep template bodies safe to evolve: any future `${expr}`
// added to the snippet stays literal instead of being treated as Dart
// interpolation.
// ignore_for_file: unnecessary_raw_strings

/// Template for a `testeador` `Fixture<T>` subclass.
///
/// Placeholders:
///   {{class_name}}    Dart class name (e.g. `SessionFixture`).
///   {{context_type}}  Concrete `T` for `Fixture<T>` (e.g. `SessionContext`).
const fixtureTemplate = r'''
import 'package:testeador/testeador.dart';

/// {{class_name}} — fixture that loads {{context_type}} before a flow runs.
class {{class_name}} extends Fixture<{{context_type}}> {
  {{class_name}}({this.onLoad});

  /// Optional callback fired with the loaded context. Lets the calling step
  /// capture per-flow state via closure without exposing the fixture's
  /// internals.
  final void Function({{context_type}} ctx)? onLoad;

  @override
  Future<{{context_type}}> load() async {
    // TODO(testeador): perform real setup here (HTTP calls, DB writes, ...).
    throw UnimplementedError('Implement {{class_name}}.load()');
  }

  @override
  Future<void> dispose({{context_type}} data) async {
    // TODO(testeador): perform real teardown here. Runs even on failure.
  }
}
''';
