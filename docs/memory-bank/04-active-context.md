# Active Context: Current Work & State

**Update this file when:** New work begins, priorities shift, or blockers are resolved.

**Last Updated:** 2026-05-23

---

## Current Focus

Multi-device streaming example just landed. The repo now has two examples and a public multidev API:

- `example/pokebattle_rest/` — the original REST example (renamed from `example/`). HTTP smoke flow unchanged; only the testeador path in its pubspec was bumped to `../../`.
- `example/pokebattle_serverpod/` — new Serverpod streaming example. Three sub-packages (`_server`, `_client`, `_flutter`). The Flutter app mirrors the REST example screen-by-screen but the lobby auto-updates via `playerAdded` / `battleAdded` streams (the AppBar shows a `● Live` chip to distinguish it).
- `lib/src/multidev/` — public API for orchestrating N emulators/simulators in parallel: `TargetDevice` / `AndroidEmulator` / `IosSimulator`, `DeviceFleet`, `FlutterActor`, `PatrolRunner`, `ScreenshotBundle`, `ScreenshotComposer` (side-by-side composite). Re-exported from `lib/testeador.dart`.

## Active Decision Points

- **Patrol granularity.** Patrol's API (taps, screenshots) lives inside `patrolTest` blocks — there is no remote channel a host process can use. testeador therefore invokes Patrol once per "agent flow" (a coherent UI scenario) per device as parallel subprocesses, and takes screenshots from the host via `adb`/`xcrun simctl` after each step. If a future Patrol release exposes a remote driver, the `PatrolRunner` indirection can be swapped without touching the smoke flows.
- **In-memory store in the Serverpod `_server`.** The mini Serverpod template skips Postgres; we keep all state in `InMemoryStore` so the example boots in seconds. Switch to a real DB if persistence across server restarts is needed.

## Recent Work Summary (from commits)

- **2026-05-23 (uncommitted):** Streaming example + multidev API as described above. See `git status` and `git diff` for the exact files.
- **1d0488e:** REST example added auth layer and private collections.
- **6c01541:** REST example client integration + contract tests.

## Next Steps (Provisional)

1. Verify end-to-end on two booted emulators (`dart test test/contract_test.dart -N streaming` from `example/pokebattle_serverpod/pokebattle_serverpod_flutter/`).
2. Capture sample `evidence/<label>/composite.png` for the README so reviewers can preview the format.
3. Consider extracting `DeviceFleet` documentation into `docs/architecture.md` once the API stabilises (currently doc-commented inline).
4. Original v1.0 roadmap still pending (TestFlowTransient rollback, pub.dev prep).

## Known Blockers

- **TestFlowTransient rollback:** Still deferred (predates streaming work).
- **Pub.dev publication:** Still deferred. The multidev API adds new dependencies (`image`) and platform expectations (`adb`/`xcrun simctl` on PATH) that need acknowledgement in the README and CI before publication.

## Team Notes

- Streaming smoke flow expects both `emulator-5554` and `emulator-5556` to be booted with the Flutter app installed. The CLI `dart run bin/snapshot_fleet.dart <label>` is the quickest way to validate device wiring without running a full test.
- Composite images live under `evidence/<label>/composite.png`. The folder is git-ignored except for its README — never commit PNGs.
