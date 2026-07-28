---
title: "feat: traffic capture engine + CDP (web) backend"
type: feat
date: 2026-06-05
part: 2 of 5
---

## feat: traffic capture engine + CDP (web) backend (PR-2) - Extensive

> Part 2 of the split from [2026-06-05-feat-contract-discovery-from-app-traffic-plan.md](2026-06-05-feat-contract-discovery-from-app-traffic-plan.md). The de-risked first backend: web/CDP, which has prior art in the repo. Native (VM Service) is deliberately deferred to PR-3.

## Dependencies

- **PR-1** (`EndpointId`) — used for deterministic seed ordering.

## Overview

Introduce the `CapturedExchange` normalized model, the `TrafficCapture` interface (kept — genuine polymorphism over two transports), and the **web** backend `CdpNetworkCapture`. Passive capture of the app's real HTTP traffic in Chrome, regardless of who drives the UI.

## Validated by spike (2026-06-06)

CDP capture was proven end-to-end before this PR: drove the real `pokebattle_rest` Flutter web app via the chrome-devtools MCP and captured method/URL/status/**request+response body** for `POST /register`, `GET /collections/players/objects`, and 20× `GET /pokemon/{name}`. See memory `project_marionette_capture_spike`. Confirmed: the 20 `/pokemon/{name}` calls make `EndpointId` templating (PR-1) mandatory (→ one `/pokemon/{id}`), and live secrets (`x-api-key`, `password`, JWT `token`) appear in the capture → redaction (PR-4) is a hard gate. Driving Flutter web required enabling the engine's semantics tree first (JS-click the "Enable accessibility" placeholder) for a11y-based interaction — relevant only when an AI/automation drives; human driving needs nothing.

## Problem & key correction

⚠️ **Review finding #3 — the original plan's reuse claim was wrong.** The existing `_Cdp` client in `lib/src/multidev/web_capture.dart` **ignores events** — it only correlates `{id}` responses and drops any message without an `int` id. `Network.enable` there is for screenshots/cookies, not traffic. CDP capture is therefore a **new capability** (event subscription + per-`requestId` body buffering), not a thin extension. Estimate accordingly (effort: M/L, not M). What *is* reusable: the Chrome launch, port/ws discovery, and `finally` cleanup in `captureWebPage`.

## Technical Approach

### `CapturedExchange` (`lib/src/capture/captured_exchange.dart`)

```dart
class CapturedExchange {
  final String method;
  final Uri url;
  final Map<String, String> requestHeaders;
  final List<int>? requestBody;
  final int? status;
  final Map<String, String> responseHeaders;
  final List<int>? responseBody;
  final String host;
  final bool partial; // response body unavailable (CDP "No data found", streamed, 304)
}
```

**`partial` semantics (review suggestion):** a partial exchange still counts toward **gap detection** (its `EndpointId` is known) but later produces a **stub-assertion** unit (status only, `// TODO: body unavailable`). It is never silently dropped — that would hide an endpoint from the gap report.

### `TrafficCapture` (`lib/src/capture/traffic_capture.dart`)

```dart
abstract interface class TrafficCapture {
  Future<void> open();
  Future<List<CapturedExchange>> takeExchanges(); // renamed from drain() — avoids Stream.drain (discard) collision
  Future<void> close();
}
```

Kept as an interface: two real transports (CDP WebSocket vs `vm_service` RPC) with a shared consumer in PR-4/PR-5. No generic base class.

### `CdpNetworkCapture` (`lib/src/capture/cdp_network_capture.dart`)

- Add an **event-aware** path to the CDP client (extend `_Cdp` with an event-stream/callback alongside its id-correlation map, or a sibling client).
- Subscribe to `Network.requestWillBeSent`, `responseReceived`, `loadingFinished`.
- Call `Network.getResponseBody(requestId)` **only inside `loadingFinished`**; on "No data found" set `partial:true` (do not crash).
- `getRequestPostData` for request bodies (note: omits multipart files).
- **Hardcode** `maxTotalBufferSize`/`maxResourceBufferSize` defaults on `Network.enable` (review: no config knob — YAGNI).
- Capture-blind diagnostic: zero exchanges ⇒ explicit warning (web-mismatch / no-traffic hint).
- Detect and **list** non-HTTP channels (WS upgrade, `text/event-stream`) — excluded from generation, reported, not dropped.
- Dart is single-threaded: a plain `List` buffer is safe; ordering is serial. Sort emitted exchanges by `EndpointId` for determinism (no concurrency primitive needed).

### Tasks

- [ ] `captured_exchange.dart`, `traffic_capture.dart` (interface with `takeExchanges`).
- [ ] Event-aware CDP client path; `cdp_network_capture.dart` per above.
- [ ] Capture-blind + non-HTTP detection/reporting.

## Testing

- [ ] E2E: drive the existing web admin-panel example, capture its real requests+responses+bodies, assert the normalized `CapturedExchange` set. Tag as integration so it doesn't gate fast CI.
- [ ] Unit (fixtures, not mocks): CDP event JSON fixtures → `CapturedExchange`; "No data found" → `partial:true`; WS/SSE classified out.
- [ ] Deterministic ordering by `EndpointId`.

## Acceptance Criteria

- [ ] `CapturedExchange` produced from real web traffic; `partial` set on missing body, never crashes.
- [ ] `TrafficCapture.takeExchanges()` returns deterministically ordered exchanges.
- [ ] Zero-exchange and WS/SSE situations reported as warnings, never "fully covered".
- [ ] Chrome process always cleaned up on failure (`finally`).
- [ ] `dart analyze` clean; `very_good test` green; memory-bank `04` updated.

## References

- `lib/src/multidev/web_capture.dart:18-211` (`_Cdp` :174-211 — **ignores events today**; Chrome launch + cleanup reusable)
- CDP Network domain: <https://chromedevtools.github.io/devtools-protocol/tot/Network/>
