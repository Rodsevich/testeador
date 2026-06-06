import 'dart:convert';

import 'package:testeador/src/capture/gap_analysis.dart';
import 'package:testeador/src/capture/secret_redactor.dart';

/// Emits a **draft** testeador contract test for one uncovered endpoint,
/// seeded from a real observed exchange.
///
/// The output is a `TestStep` builder importing only `package:testeador/...`
/// (it runs in plain CI — no marionette/vm_service), takes the target `Actor`
/// as a parameter (so a missing host never causes a compile failure — the user
/// wires it), and asserts conservatively (status + top-level response keys).
///
/// It contains **no literal secret**: request/response header values are never
/// emitted, request bodies appear only as a redacted comment, and response
/// assertions use key *names* (never the redacted values). Generated code is a
/// starting point — the header comment says so.
class TestUnitEmitter {
  /// Creates an emitter, optionally with a customized [SecretRedactor].
  TestUnitEmitter({SecretRedactor? redactor})
    : _redactor = redactor ?? SecretRedactor();

  final SecretRedactor _redactor;

  static const _dioMethods = {'get', 'post', 'put', 'patch', 'delete', 'head'};

  /// Returns the Dart source of a single contract-test builder for [gap].
  String emit(EndpointGap gap) {
    final ex = gap.seed;
    final ep = gap.endpoint;
    final path = ex.url.path.isEmpty ? '/' : ex.url.path;
    final fn = _builderName(ep.method, ep.templatedPath);
    final redactedRequest = _redactor.redactJsonBody(ex.requestBody);
    final redactedResponse = _redactor.redactJsonBody(ex.responseBody);

    final b = StringBuffer()
      ..writeln(
        '// GENERATED DRAFT by `testeador record` — review before committing.',
      )
      ..writeln('// Observed contract (secrets redacted):')
      ..writeln(
        '//   ${ep.method} ${ep.service}$path '
        '-> ${ex.status ?? '(no response captured)'}',
      );
    if (redactedRequest != null) {
      b.writeln('//   request body: $redactedRequest');
    }
    if (redactedResponse != null) {
      b.writeln('//   response body: $redactedResponse');
    }
    b
      ..writeln("import 'package:testeador/expect.dart';")
      ..writeln("import 'package:testeador/testeador.dart';")
      ..writeln()
      ..writeln(
        '/// Contract draft for `${ep.method} ${ep.templatedPath}` '
        'on `${ep.service}`.',
      )
      ..writeln(
        '/// Wire [actor] to the actor whose Dio targets `${ep.service}`, '
        'then refine.',
      )
      ..writeln('TestStep $fn(Actor actor) => TestStep(')
      ..writeln("  name: '${ep.method} ${ep.templatedPath} contract',")
      ..writeln('  action: () async {')
      ..write(_callBlock(ep.method, path, hasBody: redactedRequest != null));

    if (!ex.partial && ex.status != null) {
      b.writeln('    expect(response.statusCode, ${ex.status});');
    } else {
      b.writeln(
        '    // TODO: response not fully captured — assert the status.',
      );
    }

    final keys = _topLevelKeys(ex.responseBody);
    if (keys.isNotEmpty) {
      b
        ..writeln('    final body = response.data as Map<String, dynamic>;')
        ..writeln('    // Conservative shape checks — refine as needed.');
      for (final key in keys) {
        b.writeln("    expect(body.containsKey('${_escape(key)}'), isTrue);");
      }
    }

    b
      ..writeln('  },')
      ..writeln(');');
    return b.toString();
  }

  String _callBlock(String method, String path, {required bool hasBody}) {
    final lower = method.toLowerCase();
    final escapedPath = _escape(path);
    if (!_dioMethods.contains(lower)) {
      return '    final response = await actor.dio.request<dynamic>(\n'
          "      '$escapedPath',\n"
          "      options: Options(method: '${_escape(method)}'),\n"
          '    );\n';
    }
    if (hasBody) {
      return '    final response = await actor.dio.$lower<dynamic>(\n'
          "      '$escapedPath',\n"
          '      // TODO: supply the request body (observed shape is in the\n'
          '      // header comment above, with secrets redacted).\n'
          '    );\n';
    }
    return '    final response = '
        "await actor.dio.$lower<dynamic>('$escapedPath');\n";
  }

  List<String> _topLevelKeys(String? body) {
    if (body == null || body.isEmpty) return const [];
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded.keys.toList();
    } on FormatException {
      return const [];
    }
    return const [];
  }

  String _builderName(String method, String templatedPath) {
    final segments = templatedPath.split('/').where((s) => s.isNotEmpty);
    final parts = [
      method.toLowerCase(),
      for (final s in segments) s.replaceAll(RegExp('[^A-Za-z0-9]'), ' '),
    ];
    final pascal = parts
        .expand((p) => p.split(RegExp(r'\s+')))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join();
    return 'build${pascal}Contract';
  }

  String _escape(String raw) =>
      raw.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
}
