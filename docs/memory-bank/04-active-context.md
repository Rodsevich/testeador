# Active Context: Current Work & State

*Update when: new work begins, priorities shift, or blockers are resolved.*

**Last updated:** 2026-05-30

## Current Focus

**Web e2e + admin panel — landed 2026-05-30 (uncommitted).** `WebDevice` is now a *driven* Patrol-web target, not just an evidence surface: the fleet runs `patrol test --device chrome` against a Flutter web app, with a new Serverpod **web admin panel** as the system under test.

- **multidev:** `TargetDevice` gained `patrolDeviceId` (`WebDevice`→`'chrome'`) + `patrolExtraArgs()` (web → `--web-headless <bool> --web-viewport '{"width":W,"height":H}'`). **`--web-viewport` takes a JSON object, not `WxH`.** Pure `patrolCommandFor(device, target)` in [patrol_runner.dart](../../lib/src/multidev/patrol_runner.dart) is the single source of truth (android→serial, ios→udid, web→chrome+flags); `runOn` uses it.
- **MCP:** `run_patrol_fleet`/`boot`/`shutdown`/`snapshot` accept `platform: web` with `url`/`route`/`web_headless`/`viewport`; `list_devices` probes Chrome. **Restart a running MCP server to pick these up.**
- **Example:** web admin panel ([pokebattle_serverpod_flutter/lib/main_admin.dart](../../example/pokebattle_serverpod/pokebattle_serverpod_flutter/lib/main_admin.dart) + `lib/admin/`): players, battles+detail, force-data (seed/reset), live stream monitor; admin endpoint `client.admin.reset()/seedPlayers(n)/seedBattle()` (seeds broadcast on the channels). E2E [admin_overview_test.dart](../../example/pokebattle_serverpod/pokebattle_serverpod_flutter/integration_test/admin_overview_test.dart) — **1/1 green** both via `patrol test --device chrome` and through `PatrolRunner.runOn(WebDevice(...))`.

### Blocker resolved: testeador ↔ flutter_test (meta)

The Flutter example couldn't `pub get` (`testeador`'s analyzer ^13 → meta ^1.18 vs. `flutter_test`'s SDK-pinned meta 1.17). **Fix:** removed `testeador` from the Flutter app; host-orchestration files (`contract_test`, stream/smoke flows, `snapshot_fleet`) moved to `pokebattle_serverpod_server/tool/` + `bin/` (it resolves with testeador outside the workspace). Flutter app now depends only on `patrol ^4.0.0`. Prereqs for web e2e: Node + `dart pub global activate patrol_cli` (first run auto-installs Playwright).

## Recent landed work (uncommitted, detail in 05-progress)

- **Discover-and-pick (2026-05-29)** — `dart run testeador discover` + MCP `discover_tests`: inventory + scaffold a `TestFlow` from captured tests. 16/16 tests; E2E 2/2 in pokebattle_serverpod_server.
- **`TestInjector` codegen (2026-05-29)** — inject `package:test` bodies into flows via build_runner. 8/8 pipeline; E2E in `inject_demo/` (9/9) and the Serverpod server. Bumped analyzer 8→13.
- **Publication prep + fixes (2026-05-26, v0.3.0)** — CLI-mode `expect` (`package:testeador/expect.dart`, fixes `OutsideTestException`); tag forwarding to `group(tags:)`; CHANGELOG/.pubignore/pubspec metadata; `dart pub publish --dry-run` clean. Still `publish_to: none`.
- **MCP server (2026-05-26)** — folded into the unified `testeador` binary as the `mcp` subcommand.

## Active Decisions

- **Patrol granularity** — no remote channel exists; testeador invokes Patrol once per agent flow per device as parallel subprocesses, screenshotting from the host via `adb`/`xcrun simctl`. If Patrol later exposes a remote driver, swap `PatrolRunner` without touching flows.
- **In-memory store in the Serverpod `_server`** — skips Postgres so the example boots in seconds; switch to a real DB if cross-restart persistence is needed.

## Next Steps & Blockers

- Verify two-emulator streaming E2E; capture a sample composite for the README.
- v1.0 still pending: `TestFlowTransient` rollback, pub.dev prep (multidev adds `image` dep + `adb`/`xcrun` expectations to acknowledge).
- Flutter examples can't run build_runner yet (meta 1.17 vs 1.18); wait on Flutter SDK or pull the sub-package out of `resolution: workspace`.
- Composites live under `evidence/<label>/composite.png` (git-ignored except the README) — never commit PNGs.
