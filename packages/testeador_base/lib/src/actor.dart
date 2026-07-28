import 'package:dio/dio.dart';
import 'package:testeador_base/src/curl_interceptor.dart';

/// {@template actor}
/// Represents a user persona that executes actions in a test flow.
///
/// Subclass [Actor] to define a concrete actor with its own [Dio] instance
/// (pre-configured with base URL, auth headers, etc.).
///
/// The orchestrator automatically attaches a [CurlInterceptor] to [dio] before
/// each run, so all HTTP calls made by this actor are recorded.
///
/// Example:
/// ```dart
/// class Firesh extends Actor {
///   Firesh() : super(
///     name: 'Firesh',
///     dio: Dio(BaseOptions(baseUrl: 'https://api.example.com')),
///   );
/// }
/// ```
/// {@endtemplate}
abstract class Actor {
  /// {@macro actor}
  Actor({
    required this.name,
    Dio? dio,
    Set<String> redactHeaders = const {'authorization', 'cookie'},
  }) : dio = dio ?? Dio(),
       curlInterceptor = CurlInterceptor(redactHeaders: redactHeaders);

  /// Human-readable name for this actor (used in failure output).
  final String name;

  /// The Dio instance used by this actor for all HTTP calls.
  ///
  /// Configure base URL, default headers, auth interceptors, etc. here.
  /// A [CurlInterceptor] will be attached to this instance before running.
  ///
  /// Optional: an actor that drives a UI instead of an API gets a bare [Dio]
  /// it may never use. It still pays off — the interceptor keeps recording,
  /// so when a UI step fails the curls are there to explain what the backend
  /// did (see `UiActor` in the `testeador` package).
  final Dio dio;

  /// The interceptor recording cURL commands for this actor.
  ///
  /// Attached to [dio] by the orchestrator before each run.
  final CurlInterceptor curlInterceptor;
}
