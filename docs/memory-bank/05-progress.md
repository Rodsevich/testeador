# Progress: What Works, What's Left

*Update when: a feature reaches done, a blocker is resolved, or status changes materially.*

## What Works

### Core (v0.2.0)

- **Classes:** `Actor`, `CurlInterceptor` (records + redacts), `Fixture<T>` (load/dispose), `TestStep` (closure capture), `TestFlowLasting`, `TestFlowTransient` (marker), `TesteadorOptions`, `Testeador`.
- **Execution:** `registerWithDartTest()` (group/test blocks) and `run(args)` (CLI, exit codes); sequential within flows; standalone binary via `dart compile exe`.
- **Features:** multi-actor independent cURL logs; fixture lifecycle in `finally`; CLI filtering by tags and flow names; flags verbose / fail-fast / exit-on-failure / show-curls / show-stack-traces; header redaction (default `authorization`, `cookie`).
- **Example (REST):** PokéBattle, two actors, three flows, two real backends (PokéAPI + restful-api.dev), no mocks.

### Assertions & publication (v0.3.0)

- `package:testeador/expect.dart` — zone-independent `expect` + matchers; works in both modes, fixes the CLI `OutsideTestException`. Example flows migrated off `package:test` assertions.
- `registerWithDartTest()` forwards `flow.tags` to `group(tags:)` so `dart test --tags` matches the CLI.
- `CHANGELOG.md`, pubspec metadata (`repository`/`homepage`/`issue_tracker`/`topics`), `.pubignore`; `dart pub publish --dry-run` clean. Still `publish_to: none`.

### Example (Serverpod streaming)

- Mini Serverpod project (`server` + `client` + `flutter`); streaming endpoints fan out via `session.messages` (`playerAdded`, `battleAdded`, `battleUpdates`); Flutter lobby auto-updates with a `● Live` chip.
- Patrol agent flows + a testeador smoke flow driving Patrol on two devices in parallel, capturing `evidence/<label>/composite.png` per step.

### Multi-device evidence (`lib/src/multidev/`)

- `TargetDevice` (`AndroidEmulator`/`IosSimulator`/`WebDevice`) with boot/shutdown/screenshot; `DeviceFleet` (`snapshot`, `snapshotComposite`, `runPatrolAcross`, `runPatrolOn`); `FlutterActor`; `PatrolRunner`; `ScreenshotComposer.sideBySide` (the canonical AI-review artifact); CLI `bin/snapshot_fleet.dart`.
- **Web as a driven device** — `WebDevice`→`chrome`; pure `patrolCommandFor`; web admin panel e2e **1/1 green** in real headless Chrome (see [04-active-context.md](04-active-context.md)).

### MCP server (`lib/src/mcp/`, `testeador mcp`)

- Built on `mcp_dart` (stdio); resolves the target project via `TESTEADOR_PROJECT_ROOT` or CWD walk-up.
- **Introspection:** `list_suites`, `inspect_suite` (analyzer AST), `list_tags`, `dry_run_suite` (reuses public `filterFlows`). **Execution:** `run_suite_cli`, `run_suite_dart_test`, `compile_suite_exe` (all support `execute: false`). **Scaffolding:** `scaffold_actor/fixture/flow/suite_runner/dart_test_main` (`dry_run`; refuse overwrite). **Multidev** (gated by `TESTEADOR_MCP_ENABLE_MULTIDEV=1`): `list_devices`, `boot/shutdown/snapshot_fleet`, `run_patrol_fleet`.
- Resources (`testeador://templates/*`, `testeador://docs/*`) + prompts (`scaffold_suite`, `diagnose_failure`). Tests under `test/mcp/` passing; `.mcp.json` wired.

### `TestInjector` codegen + discover-and-pick

- **Codegen:** capture shim for `package:test`, AST scanner, source transformer, identifier namer, aggregator emitting `lib/test_injector.g.dart` (`byName`/`byTags`/`byRegExp`); builders in `build.yaml`. 8/8 pipeline tests; E2E in `inject_demo/` (9/9) and `pokebattle_serverpod_server` (8/8).
- **Discover:** `dart run testeador discover` (text/JSON, filters, `--pick`, emits a flow entrypoint) + MCP `discover_tests` (subprocess wrapper); discovery lib walks `package_config.json` manifests; shared `safeWrite`. 16/16 tests; E2E pick 2 → `dart test` 2/2 green.

### Docs

- README (usage/CLI/MCP), architecture.md (spec + diagrams + glossary), PROBLEM.md (Spanish narrative), roadmap.md, PRD.md, example READMEs.

## Pending / TODO

- **`TestFlowTransient` rollback** — marker only; pick a strategy (transaction-scope callback vs. `RollbackStrategy` vs. DB-specific). Deferred pending usage data.
- **Pub.dev publication** — flip `publish_to`; confirm API stability, license, docs; acknowledge multidev's `image` dep + `adb`/`xcrun` expectations.
- **True cross-package injection** — capture in one package, inject from a dependent package (validate `auto_apply: dependents`).
- **Flutter-host build_runner** — blocked by `flutter_test` meta 1.17 vs analyzer's 1.18; wait on Flutter SDK or pull the sub-package out of `resolution: workspace`.
- **Nice-to-have:** improved error messages, multiple fixtures, custom error handlers, latency assertions, OpenAPI/GraphQL doc generation, CI integration examples.

## Known Issues

- **`TestFlowTransient` has no rollback** — read-only flows must use `TestFlowLasting`; side effects persist. Workaround: label logically read-only flows.
- **External API dependency** — tests fail if PokéAPI/restful-api.dev are down; use staging APIs under your control.
- **Closure-capture complexity** — many-step flows capture a lot of state; keep flows focused, use clear names.
- **`dart compile exe` binary size** — 100+ MB on macOS (AOT); `strip` to shrink.

## Versions

| Version | Status | Notes |
| --- | --- | --- |
| 0.1.0 | Archived | Initial implementation (see git history) |
| 0.2.0 | Stable | Dual-mode execution; Pokémon example |
| 0.3.0 | In-flight (uncommitted) | CLI-mode `expect`, MCP server, codegen, discover, web e2e, publication prep |
| 1.0 | Candidate | `TestFlowTransient` rollback; pub.dev; API finalized |
