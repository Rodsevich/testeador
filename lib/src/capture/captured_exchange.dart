import 'package:meta/meta.dart';
import 'package:testeador/src/contract/endpoint_id.dart';

/// A single HTTP request/response pair observed while a real app was exercised.
///
/// This is the normalized shape every capture backend produces — the CDP
/// (web) backend and the VM-service (native) backend reconcile their very
/// different wire formats to this one model so the rest of the pipeline never
/// has to care where a capture came from.
///
/// Bodies are kept as decoded text (contracts are JSON in practice); a body
/// that could not be decoded or retrieved is `null` and [partial] is `true`.
@immutable
class CapturedExchange {
  /// Creates a captured exchange.
  const CapturedExchange({
    required this.method,
    required this.url,
    required this.requestHeaders,
    required this.responseHeaders,
    this.requestBody,
    this.status,
    this.responseBody,
    this.partial = false,
  });

  /// HTTP method as observed; [endpointId] upper-cases it for identity.
  final String method;

  /// Full request URL, including query (query is dropped only at [endpointId]).
  final Uri url;

  /// Request headers (lower-cased keys where the backend provides them).
  final Map<String, String> requestHeaders;

  /// Request body as text, or `null` when absent or non-text.
  final String? requestBody;

  /// Response status code, or `null` when the response had not completed when
  /// capture ended (an in-flight request) — see [partial].
  final int? status;

  /// Response headers (lower-cased keys where the backend provides them).
  final Map<String, String> responseHeaders;

  /// Response body as text, or `null` when unavailable — see [partial].
  final String? responseBody;

  /// `true` when the response body and/or status could not be captured (the
  /// request was still in flight, the body was evicted, streamed, or 304).
  ///
  /// A partial exchange still counts toward gap detection — its [endpointId]
  /// is known — but downstream generation seeds only a status-level stub.
  final bool partial;

  /// Host the request targeted (the default [endpointId] service).
  String get host => url.host;

  /// The endpoint identity this exchange contributes to the coverage diff.
  EndpointId endpointId({String? service}) =>
      normalizeEndpoint(method: method, url: url, service: service);

  @override
  String toString() =>
      '$method ${url.path} -> ${status ?? '(pending)'}'
      '${partial ? ' [partial]' : ''}';
}
