import 'package:meta/meta.dart';

/// The canonical identity of a backend endpoint, shared by every part of the
/// contract-discovery feature.
///
/// Both sides of the coverage diff — the endpoints a real app *exercises* and
/// the endpoints existing tests *cover* — must be reduced to an [EndpointId]
/// with the **same** [normalizeEndpoint] function, or the diff is meaningless.
///
/// Identity is `(method, templatedPath, service)`. The HTTP status code and
/// query parameters are attributes of an observed contract, **not** part of
/// identity: `GET /users/{id}` and `GET /users/{id}?expand=team` are the same
/// endpoint, and a 200 vs a 404 to that path do not make two endpoints.
@immutable
class EndpointId {
  /// Creates an endpoint identity. Prefer [normalizeEndpoint] over calling
  /// this directly so the templating rules are applied consistently.
  const EndpointId({
    required this.method,
    required this.templatedPath,
    required this.service,
  });

  /// Hydrates an [EndpointId] from its [toJson] form.
  ///
  /// The path is stored under the `path` key (it is already templated).
  factory EndpointId.fromJson(Map<String, dynamic> json) => EndpointId(
    method: json['method'] as String,
    templatedPath: json['path'] as String,
    service: json['service'] as String,
  );

  /// Upper-cased HTTP method, e.g. `GET`, `POST`.
  final String method;

  /// Path with volatile segments replaced by `{id}`, e.g. `/users/{id}`.
  final String templatedPath;

  /// Host or logical service the endpoint belongs to, e.g. `api.example.com`.
  /// Lets the diff group endpoints per microservice.
  final String service;

  /// JSON form persisted inside a test's `coveredEndpoints` in the manifest.
  Map<String, dynamic> toJson() => {
    'method': method,
    'path': templatedPath,
    'service': service,
  };

  @override
  bool operator ==(Object other) =>
      other is EndpointId &&
      other.method == method &&
      other.templatedPath == templatedPath &&
      other.service == service;

  @override
  int get hashCode => Object.hash(method, templatedPath, service);

  @override
  String toString() => '$method $service$templatedPath';
}

final _numeric = RegExp(r'^\d+$');
final _uuid = RegExp(
  r'^[\da-fA-F]{8}-[\da-fA-F]{4}-[\da-fA-F]{4}-'
  r'[\da-fA-F]{4}-[\da-fA-F]{12}$',
);
// Long bare-hex segments: Mongo ids (24), 32-char ids, dashless UUIDs, etc.
final _longHex = RegExp(r'^[\da-fA-F]{12,}$');

/// Reduces a concrete request to its [EndpointId].
///
/// Path segments that look like identifiers — all-digits, a UUID, or a long
/// hexadecimal blob — collapse to `{id}` so that `/users/1` and `/users/2`
/// map to a single `/users/{id}`. [service] defaults to the URL host.
/// Query parameters and fragments are dropped (they are not part of identity).
///
/// The function is idempotent: feeding it an already-templated path yields the
/// same result (the literal segment `{id}` is preserved).
EndpointId normalizeEndpoint({
  required String method,
  required Uri url,
  String? service,
}) {
  final segments = url.pathSegments.where((s) => s.isNotEmpty).map(_template);
  return EndpointId(
    method: method.toUpperCase(),
    templatedPath: '/${segments.join('/')}',
    service: service ?? url.host,
  );
}

String _template(String segment) {
  // An already-templated `{id}` matches none of these (it contains braces),
  // so it falls through unchanged — keeping normalizeEndpoint idempotent.
  if (_numeric.hasMatch(segment)) return '{id}';
  if (_uuid.hasMatch(segment)) return '{id}';
  if (_longHex.hasMatch(segment)) return '{id}';
  return segment;
}
