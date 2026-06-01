# Changelog

All notable changes to this project are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- **`WebDevice` — a driven web target for the multi-device fleet.** A
  `TargetDevice` subtype for Flutter web apps that serves two roles:
  - **Driven e2e (Patrol-web).** `TargetDevice` gained `patrolDeviceId`
    (web → `chrome`) and `patrolExtraArgs()` (web → `--web-headless <bool>
    --web-viewport '{"width":W,"height":H}'`), so a fleet runs
    `patrol test --device chrome …` against it (Patrol 4.0+ drives Flutter web
    via Playwright). The new pure `patrolCommandFor(device, target)` is the
    single source of truth shared by `PatrolRunner.runOn` and the MCP
    `run_patrol_fleet` planned-command preview.
  - **Evidence surface.** `screenshot()` drives headless Chrome over the
    DevTools Protocol (`lib/src/multidev/web_capture.dart`, pure Dart — no
    Node): navigate to `currentUrl` (`baseUrl` + a mutable `route`), **poll
    `readyExpression` until the SPA is past its splash** (default: Flutter's
    `flutter-view` attached), `settle`, then capture. The previous one-shot
    `chrome --headless --screenshot` photographed the app mid-bootstrap (stuck
    on its splash); CDP keeps a real event loop so the rendered UI is captured.
    Optional `cookies` (injected via `Network.setCookie`) and `initScript`
    (`Page.addScriptToEvaluateOnNewDocument`) seed an auth session / base URL so
    a guarded route shows real content instead of a login wall. The Chrome
    process is always killed and its temp profile removed, even on failure.
    This lets a fleet put a logged-in web admin panel side-by-side with mobile
    sims in `snapshotComposite`.

  The MCP multidev tools accept `platform: "web"` with `url`, `route`,
  `web_headless`, and `viewport` fields; `list_devices` reports a `web` target
  via a Chrome probe. Web e2e needs Node + `patrol_cli` 4.x.
- **Web admin panel example.** `pokebattle_serverpod` ships a web admin panel
  (`pokebattle_serverpod_flutter/lib/main_admin.dart`) — players, battles,
  force-data (`client.admin.reset/seedPlayers/seedBattle`), and a live stream
  monitor — driven end-to-end in real Chrome by
  `integration_test/admin_overview_test.dart`.

## 0.3.0

### Added

- **Unified `testeador` CLI with subcommands.** A single package executable
  (`bin/testeador.dart`) replaces the per-feature binaries. Subcommands:
  - **`testeador mcp`** — Model Context Protocol server exposing every
    testeador feature to MCP clients (Claude Code, Cursor, etc.). Tool groups:
    introspection (`list_suites`, `inspect_suite`, `list_tags`,
    `dry_run_suite`), execution (`run_suite_cli`, `run_suite_dart_test`,
    `compile_suite_exe`), scaffolding (`scaffold_actor`/`fixture`/`flow`/
    `suite_runner`/`dart_test_main`), discovery (`discover_tests`), and
    multidev (`list_devices`, `boot_fleet`, `shutdown_fleet`, `snapshot_fleet`,
    `run_patrol_fleet`, gated behind `TESTEADOR_MCP_ENABLE_MULTIDEV=1`). Also
    ships scaffolding templates and project docs as MCP resources, plus
    `scaffold_suite` and `diagnose_failure` prompts.
  - **`testeador discover`** — lists captured tests from build_runner
    manifests and scaffolds a `TestFlow` from a picked subset (also wrapped
    by the `discover_tests` MCP tool).
- **Zone-independent assertions.** testeador now exports its own synchronous
  `expect` plus the `package:matcher` matchers. Use `expect(...)` from
  `package:testeador/testeador.dart` in flows so the *same* flow asserts
  correctly under both `Testeador.run()` (CLI) and `registerWithDartTest()`.
- **Public `filterFlows(flows, options)`.** The flow include/exclude filtering
  logic is now a top-level function, so external runners compute the exact
  same set of flows the orchestrator executes.
- **Tag forwarding in `registerWithDartTest()`.** Each flow's `tags` are now
  passed to its `group()`, so `dart test --tags <t>` filters consistently with
  the CLI's `--include-tags` / `--exclude-tags`.

### Fixed

- **`expect` no longer throws `OutsideTestException` in CLI mode.** Previously,
  flows that used `package:test`'s `expect` passed under `dart test` but threw
  `OutsideTestException` when run via the standalone CLI / compiled binary —
  the package's primary CI mode. Flows now use testeador's `expect`, which
  throws a plain `TestFailure` that works in both modes.

### Changed

- `mcp_dart`, `analyzer`, `matcher`, `meta`, and `path` are now direct
  dependencies (required by the MCP server and the assertion API).

## 0.2.0

- Dual-mode orchestration: `registerWithDartTest()` (integrates with
  `package:test`) and `run(args)` (standalone CLI binary with tag/flow
  filtering, fail-fast, cURL logging, stack traces).
- `Actor`, `Fixture<T>`, `TestStep`, `TestFlowLasting`, `TestFlowTransient`,
  `CurlInterceptor`, `TesteadorOptions`.
- Multi-device evidence API (`lib/src/multidev/`): `TargetDevice`
  (`AndroidEmulator`, `IosSimulator`), `DeviceFleet`, `FlutterActor`,
  `PatrolRunner`, `ScreenshotComposer`.
- PokéBattle examples: REST (`pokebattle_rest`) and Serverpod streaming
  (`pokebattle_serverpod`), exercising real HTTP backends with no mocks.

## 0.1.0

- Initial implementation.
