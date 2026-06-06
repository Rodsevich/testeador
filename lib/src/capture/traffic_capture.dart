import 'package:testeador/src/capture/captured_exchange.dart';

/// A passive sink for the HTTP traffic a running app generates.
///
/// Two backends implement this over very different transports — Chrome
/// DevTools Protocol for Flutter web, the Dart VM-service HTTP profiler for
/// native — but both reduce what they see to [CapturedExchange]s. Capture is
/// *passive*: it observes whatever the app does regardless of who drives the
/// UI (a human tapping, or an AI via marionette).
///
/// Lifecycle: [open] before the journey (it must enable profiling *first* —
/// enabling late captures nothing), then [takeExchanges] to drain what was
/// seen, then [close]. Implementations must always release their transport in
/// [close], even after an error.
abstract interface class TrafficCapture {
  /// Connects and starts recording. Must be called before any traffic to
  /// capture occurs.
  Future<void> open();

  /// Returns the exchanges observed so far, in a deterministic order
  /// (by endpoint identity, not arrival), and awaits any in-progress body
  /// retrieval. Safe to call once after the journey.
  Future<List<CapturedExchange>> takeExchanges();

  /// Releases the transport. Idempotent and best-effort.
  Future<void> close();
}
