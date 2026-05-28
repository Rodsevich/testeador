// Raw strings keep template bodies safe to evolve: any future `${expr}`
// added to the snippet stays literal instead of being treated as Dart
// interpolation, so MCP clients see the source as it would appear in a
// scaffolded file.
// ignore_for_file: unnecessary_raw_strings

/// Template for a `testeador` Actor subclass.
///
/// Placeholders:
///   {{class_name}}    Dart class name (e.g. `FireshActor`).
///   {{actor_name}}    Human-readable name for failure logs (e.g. `Firesh`).
///   {{base_url}}      Optional base URL; left blank means a bare `Dio()`.
const actorTemplate = r'''
import 'package:dio/dio.dart';
import 'package:testeador/testeador.dart';

/// {{class_name}} — actor used in testeador flows.
class {{class_name}} extends Actor {
  {{class_name}}()
      : super(
          name: '{{actor_name}}',
          dio: Dio({{dio_options}}),
        );
}
''';
