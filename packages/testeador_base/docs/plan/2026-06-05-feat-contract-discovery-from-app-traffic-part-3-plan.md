---
title: "feat: native VM Service HTTP capture backend"
type: feat
date: 2026-06-05
part: 3 of 5
---

## feat: native VM Service HTTP capture backend (PR-3) - Standard

> Part 3 of the split from [2026-06-05-feat-contract-discovery-from-app-traffic-plan.md](2026-06-05-feat-contract-discovery-from-app-traffic-plan.md). The highest-risk backend, isolated in its own PR (no prior art in repo; new dependency; real blind spot). Web already works from PR-2, so the feature is usable without this.

## Dependencies

- **PR-2** (`TrafficCapture` interface + `CapturedExchange`).

## Overview

Add `VmServiceHttpCapture`, the second concrete `TrafficCapture`, for native apps (Android/iOS/desktop) using the Dart VM Service HTTP profiler. Reconciles to the same `CapturedExchange` model as the CDP backend.

## Problem & risk (review finding #2 — biggest architectural risk)

The VM Service HTTP profiler only sees traffic through `dart:io HttpClient`. Apps using `native_dio_adapter` (Cronet on Android, Cupertino/NSURLSession on iOS — common in production) route HTTP **outside** `dart:io`, so the profiler captures **nothing**. A silent under-capture reports "covered" when it isn't — the exact false-confidence failure VGV testing standards exist to prevent.

**Mitigation is gating, not just a warning:**
- [ ] **Spike first:** before committing the `vm_service` dependency, prove capture works against the actual example app's dio adapter. If the example uses a native adapter, switch it to the default `dart:io` adapter for the spike and document the limitation.
- [ ] Hard-warn (loud, in the gap report) when zero/low exchanges are captured, naming the native-adapter cause explicitly.

## Validated by spike (2026-06-06)

The capture mechanism was proven end-to-end before writing this PR (Dio over `dart:io` under `dart --observe`, read with `package:vm_service`). See memory `project_marionette_capture_spike`. Confirmed:
- `getHttpProfileRequest` returns `requestBody`/`responseBody` (`Uint8List`) + headers + `response.statusCode`, **even for error responses** (captured a 403 with its body).
- **Profiling must be enabled BEFORE traffic.** Enabling late captured **0** requests. So `open()` must call `httpEnableTimelineLogging(isolateId, true)` (or the app sets `HttpClient.enableTimelineLogging = true`) at the **start of the bracket**, before the journey.
- A request in flight appears with `statusCode == null` and empty body → `partial:true` is real; handle gracefully.
- `user-agent: Dart/<v> (dart:io)` confirms the default Dio adapter is captured; `native_dio_adapter` would be invisible (G4 stands, scoped to explicit native adapters).

API shape (vm_service 15.x): `service.getHttpProfile(isolateId)` → `HttpProfile.requests`; `service.getHttpProfileRequest(isolateId, ref.id)` → `.method`, `.uri`, `.request?.headers`, `.requestBody`, `.response?.statusCode`, `.responseBody`.

## Technical Approach

- [ ] Add `vm_service` to `pubspec.yaml` (this PR is where it's first used).
- [ ] `lib/src/capture/vm_service_capture.dart`:
  - Connect via a supplied VM service / **DDS URI in attach mode (default)** — share the connection an agent/marionette already opened; never steal it (DDS single-client coexistence — G11).
  - **`open()` enables profiling first** via `httpEnableTimelineLogging(isolateId, true)` before any journey traffic (validated: late-enable captures nothing).
  - `getHttpProfile` / `getHttpProfileRequest` → headers, `requestBody`/`responseBody` (Uint8List), status, timing → `CapturedExchange`; in-flight request (`statusCode == null`) → `partial:true`.
  - Hard-warn on native-adapter bypass (G4).

## Testing

- [ ] E2E: drive the Serverpod Flutter example (default dio adapter), capture native traffic, assert the normalized model is **identical in shape** to the CDP backend's output. Integration-tagged.
- [ ] Unit (fixtures): `HttpProfileRequest` JSON fixtures → `CapturedExchange`.

## Acceptance Criteria

- [ ] `VmServiceHttpCapture` produces `CapturedExchange` identical in shape to CDP.
- [ ] Attach mode is default; no DDS single-client conflict with an active marionette session.
- [ ] Native-adapter / zero-capture reported loudly, never "fully covered".
- [ ] `dart analyze` clean; `very_good test` green; memory-bank `04` updated.

## References

- VM Service profiler: <https://pub.dev/documentation/vm_service/latest/vm_service/HttpProfileRequest-class.html>, <https://api.flutter.dev/flutter/vm_service/DartIOExtension.html>
- Native-adapter future path: `http_profile` — <https://pub.dev/packages/http_profile>
- marionette (connection coexistence): <https://github.com/leancodepl/marionette_mcp>
