import 'dart:convert';
import 'dart:io';

import 'package:testeador/src/capture/captured_exchange.dart';
import 'package:testeador/src/capture/traffic_capture.dart';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

/// Builds a [CapturedExchange] from the raw fields of a VM-service
/// `HttpProfileRequest`.
///
/// Kept transport-free and public so it can be unit-tested with plain data
/// (no live VM, no mocks). Header maps may carry `List` values (multi-valued
/// headers) which are joined with `, `; keys are lower-cased to match the CDP
/// backend. Bodies are decoded as UTF-8 text (contracts are JSON in practice);
/// empty or undecodable bytes become `null`. A `null` status means the request
/// was still in flight when the profile was read, so the exchange is partial.
CapturedExchange mapVmHttpExchange({
  required String method,
  required Uri uri,
  Map<String, dynamic>? requestHeaders,
  List<int>? requestBody,
  int? statusCode,
  Map<String, dynamic>? responseHeaders,
  List<int>? responseBody,
}) {
  return CapturedExchange(
    method: method,
    url: uri,
    requestHeaders: _flattenHeaders(requestHeaders),
    responseHeaders: _flattenHeaders(responseHeaders),
    requestBody: _decodeBody(requestBody),
    status: statusCode,
    responseBody: _decodeBody(responseBody),
    partial: statusCode == null,
  );
}

Map<String, String> _flattenHeaders(Map<String, dynamic>? headers) {
  if (headers == null) return const {};
  return {
    for (final e in headers.entries)
      e.key.toLowerCase(): e.value is List
          ? (e.value as List).join(', ')
          : '${e.value}',
  };
}

String? _decodeBody(List<int>? bytes) {
  if (bytes == null || bytes.isEmpty) return null;
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return null;
  }
}

/// [TrafficCapture] backend for **native** apps (Android/iOS/desktop): reads
/// the Dart VM-service HTTP profiler over a VM-service / DDS WebSocket URI.
///
/// Attach mode — point it at the URI an already-running app exposes (the same
/// one an AI/marionette session may hold; DDS multiplexes, so this shares
/// rather than steals the connection). [open] enables HTTP timeline logging
/// **before** the journey, because enabling it late records nothing.
///
/// Captures only traffic that flows through `dart:io HttpClient` (Dio's and
/// `package:http`'s default adapters). An app using a native adapter
/// (`cronet_http`/`cupertino_http` via `native_dio_adapter`) bypasses
/// `dart:io`, so zero captures are reported with an explicit hint rather than
/// silently treated as "no traffic".
///
/// The wire transport needs a live VM and cannot be unit-tested without mocks;
/// its field-mapping core is [mapVmHttpExchange], which is tested directly.
class VmServiceHttpCapture implements TrafficCapture {
  /// Attaches to the VM service / DDS at [wsUri] (e.g. `ws://127.0.0.1:PORT/ws`).
  /// [onWarning] receives capture-blind diagnostics (defaults to stderr).
  VmServiceHttpCapture({
    required String wsUri,
    void Function(String message)? onWarning,
  }) : _wsUri = wsUri,
       _onWarning = onWarning ?? stderr.writeln;

  final String _wsUri;
  final void Function(String message) _onWarning;

  VmService? _service;
  String? _isolateId;

  @override
  Future<void> open() async {
    final service = await vmServiceConnectUri(_wsUri);
    _service = service;
    final vm = await service.getVM();
    final isolates = vm.isolates;
    if (isolates == null || isolates.isEmpty) {
      throw StateError('No isolates on the VM service at $_wsUri.');
    }
    final isolateId = isolates.first.id!;
    _isolateId = isolateId;
    // Enable HTTP profiling BEFORE the journey — enabling it late records
    // nothing (the buffer only fills while logging is on).
    await service.httpEnableTimelineLogging(isolateId, true);
  }

  @override
  Future<List<CapturedExchange>> takeExchanges() async {
    final service = _service!;
    final isolateId = _isolateId!;
    final profile = await service.getHttpProfile(isolateId);

    final exchanges = <CapturedExchange>[];
    for (final ref in profile.requests) {
      final full = await service.getHttpProfileRequest(isolateId, ref.id);
      exchanges.add(
        mapVmHttpExchange(
          method: full.method,
          uri: full.uri,
          requestHeaders: full.request?.headers,
          requestBody: full.requestBody,
          statusCode: full.response?.statusCode,
          responseHeaders: full.response?.headers,
          responseBody: full.responseBody,
        ),
      );
    }
    exchanges.sort(
      (a, b) => a.endpointId().toString().compareTo(b.endpointId().toString()),
    );

    if (exchanges.isEmpty) {
      _onWarning(
        'captured 0 HTTP exchanges via the VM service. If the app uses a '
        'native HTTP adapter (cronet_http / cupertino_http via '
        'native_dio_adapter), its traffic bypasses dart:io and the profiler '
        'cannot see it.',
      );
    }
    return exchanges;
  }

  @override
  Future<void> close() async {
    await _service?.dispose();
    _service = null;
    _isolateId = null;
  }
}
