# Active Context: Current Work & State

**Update this file when:** New work begins, priorities shift, or blockers are resolved.

**Last Updated:** 2026-05-26

---

## Current Focus

**Publication prep + two correctness fixes (2026-05-26, uncommitted), bumped to v0.3.0.**

- **CLI-mode assertions fixed.** `package:test`'s `expect` (and even `package:matcher`'s) call `TestHandle.current`, throwing `OutsideTestException` outside a runner — so flows asserted fine under `dart test` but crashed under `Testeador.run()` (the CLI/binary CI mode). testeador now ships its own synchronous `expect` in `lib/src/expectations.dart`, exposed via a dedicated `package:testeador/expect.dart` import (NOT the main barrel — re-exporting matcher's namespace there collides with `package:test` in runner files). Flows import both `testeador.dart` and `expect.dart`; they must NOT import `package:test`. This was caught by running the REST e2e through the MCP.
- **Tag forwarding fixed.** `registerWithDartTest()` now passes `flow.tags` to `group(..., tags:)` so `dart test --tags` filters like the CLI's `--include-tags`.
- **Publication metadata.** Added `CHANGELOG.md`, `.pubignore` (excludes `docs/`, `evidence/`, `.env*`, build dirs — also clears the "rename docs/ to doc/" warning), and `repository`/`homepage`/`issue_tracker`/`topics` in pubspec. `dart pub publish --dry-run` is clean except the expected "git dirty" warning. Still `publish_to: none` — flip to publish.
- **E2E evidence** under `evidence/e2e-rest/` (7/7 flows green in CLI mode, smoke green via `dart test`) and `evidence/mcp-e2e-sim/` (iOS simulator composite captured via the MCP `snapshot_fleet` tool).

**MCP server (`testeador_mcp`) landed earlier this session (2026-05-26, uncommitted).** testeador now ships an MCP server that exposes every feature of the package to MCP clients. Implementation under `lib/src/mcp/`, entrypoint `bin/testeador_mcp.dart`, declared as the `testeador_mcp` executable in `pubspec.yaml`. `mcp_dart`, `analyzer`, `path`, and `meta` were promoted to `dependencies` (not dev) so `dart pub global activate testeador` can build the executable.

- **Tool groups:** introspection (`list_suites`, `inspect_suite`, `list_tags`, `dry_run_suite`), execution (`run_suite_cli`, `run_suite_dart_test`, `compile_suite_exe` — each with `execute: false` command-only mode), scaffolding (`scaffold_actor/fixture/flow/suite_runner/dart_test_main` — each with `dry_run`), multidev (`list_devices`, `boot_fleet`, `shutdown_fleet`, `snapshot_fleet`, `run_patrol_fleet` — gated by `TESTEADOR_MCP_ENABLE_MULTIDEV=1`).
- **Resources/prompts:** `testeador://templates/*` and `testeador://docs/*` resources; `scaffold_suite` and `diagnose_failure` prompts.
- **Internal change:** `Testeador._filter` was extracted to the public top-level `filterFlows(flows, options)` (exported from `lib/testeador.dart`) so `dry_run_suite` reuses the exact runtime filter logic.
- **`.mcp.json`:** a `testeador` server entry was added alongside `dart`/`patrol`/`serverpod`.
- The suite inspector parses the *unresolved* AST, where `Testeador(...)`/`TestFlowLasting(...)`/`TestStep(...)` (no `new`) are `MethodInvocation`s, not `InstanceCreationExpression`s — `_callInfo` normalizes both.

Earlier context — multi-device streaming example. The repo has two examples and a public multidev API:

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
