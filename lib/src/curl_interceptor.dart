import 'package:dio/dio.dart';

/// A Dio interceptor that records every outgoing request as a cURL command.
class CurlInterceptor extends Interceptor {
  /// Creates a [CurlInterceptor] with an optional set of headers to redact.
  CurlInterceptor({
    this.redactHeaders = const {'authorization', 'cookie'},
  });

  final List<String> _log = [];

  /// Headers whose values are replaced with `[REDACTED]` in the log.
  final Set<String> redactHeaders;

  /// All recorded cURL commands in order.
  List<String> get log => List.unmodifiable(_log);

  /// Clears the recorded log.
  void clear() => _log.clear();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _log.add(_toCurl(options));
    handler.next(options);
  }

  String _toCurl(RequestOptions options) {
    final buffer = StringBuffer('curl -X ${options.method}');

    options.headers.forEach((key, value) {
      final lowerKey = key.toLowerCase();
      final displayValue = redactHeaders.contains(lowerKey)
          ? '[REDACTED]'
          : value;
      buffer.write(" -H '$key: $displayValue'");
    });

    if (options.data != null) {
      buffer.write(" -d '${options.data}'");
    }

    buffer.write(" '${options.uri}'");
    return buffer.toString();
  }
}
