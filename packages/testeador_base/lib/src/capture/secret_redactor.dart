import 'dart:convert';

/// Strips secrets from values that would otherwise be written into generated
/// test source (which gets committed to a repo — worse than the log case).
///
/// Two surfaces: HTTP header values (`authorization`, `cookie`, API keys) and
/// structured body fields whose key names look secret (`*token*`, `*secret*`,
/// `*password*`, `*apikey*`). Redacted values become the sentinel
/// [placeholder]; the emitter never turns a redacted value into an assertion.
/// Non-JSON bodies are dropped wholesale ([nonJsonBody]) because they cannot be
/// inspected field-by-field and may carry form-encoded credentials.
class SecretRedactor {
  /// Creates a redactor, optionally widening the default sensitive sets.
  SecretRedactor({
    Set<String> extraHeaderKeys = const {},
    Set<String> extraBodyKeys = const {},
  }) : _headerKeys = {..._defaultHeaderKeys, ...extraHeaderKeys},
       _extraBodyKeys = extraBodyKeys.map((k) => k.toLowerCase()).toSet();

  /// Replacement written in place of any redacted value.
  static const String placeholder = '<redacted>';

  /// Replacement for a body that could not be parsed as JSON.
  static const String nonJsonBody = '<non-JSON body omitted>';

  static const Set<String> _defaultHeaderKeys = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'api-key',
  };

  static final RegExp _bodyKeyPattern = RegExp(
    'token|secret|password|apikey|api_key',
    caseSensitive: false,
  );

  final Set<String> _headerKeys;
  final Set<String> _extraBodyKeys;

  /// Whether [key] names a sensitive header (case-insensitive).
  bool isSensitiveHeader(String key) => _headerKeys.contains(key.toLowerCase());

  /// Whether [key] names a sensitive body field.
  bool isSensitiveBodyKey(String key) =>
      _bodyKeyPattern.hasMatch(key) ||
      _extraBodyKeys.contains(key.toLowerCase());

  /// Returns [headers] with sensitive values replaced by [placeholder].
  Map<String, String> redactHeaders(Map<String, String> headers) => {
    for (final e in headers.entries)
      e.key: isSensitiveHeader(e.key) ? placeholder : e.value,
  };

  /// Returns [body] re-serialized with sensitive fields replaced by
  /// [placeholder]. A `null` body returns `null`; a body that is not valid
  /// JSON returns [nonJsonBody] (dropped, never echoed verbatim).
  String? redactJsonBody(String? body) {
    if (body == null || body.isEmpty) return body;
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      return nonJsonBody;
    }
    return const JsonEncoder().convert(_redactNode(decoded));
  }

  Object? _redactNode(Object? node) {
    if (node is Map) {
      return {
        for (final e in node.entries)
          e.key: isSensitiveBodyKey('${e.key}')
              ? placeholder
              : _redactNode(e.value),
      };
    }
    if (node is List) return node.map(_redactNode).toList();
    return node;
  }
}
