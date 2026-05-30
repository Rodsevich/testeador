# Active Context: Current Work & State

**Update this file when:** New work begins, priorities shift, or blockers are resolved.

**Last Updated:** 2026-05-29

---

## Current Focus

**Discover-and-pick (CLI + MCP) — landed 2026-05-29 (uncommitted).** Plan: `~/.claude/plans/podemos-hacer-una-feature-hidden-seahorse.md`.

New surface for the codegen feature: an inventory + scaffold flow built on top of the existing capture-manifest artifacts.

- **CLI binary**: unified entrypoint [bin/testeador.dart](../../bin/testeador.dart) with `discover` subcommand (`dart run testeador discover`). Body lives in [lib/src/discovery/cli.dart](../../lib/src/discovery/cli.dart). Lists captured tests (text or `--json`), filters (`--tag`, `--pattern`, `--package-name`), picks (`--pick <fqId>` repeated) and emits a `dart test` entrypoint via a new template. Supports `--print` (snippet to stdout), `--out <path>` (default `test/picked_flow_test.dart`), `--dry-run`, `--flow-name`, `--flow-function`, `--kind {lasting|transient}`, `--flow-tags`, `--description`, `--package`.
- **MCP tool**: `discover_tests` in [lib/src/mcp/tools/discovery_tools.dart](../../lib/src/mcp/tools/discovery_tools.dart) — thin subprocess wrapper around the CLI; single source of truth for list/scaffold logic. Wired through [lib/src/mcp/tools/tools.dart](../../lib/src/mcp/tools/tools.dart).
- **Discovery lib** (pure-Dart, no I/O dependencies other than `dart:io`): [lib/src/discovery/manifest_reader.dart](../../lib/src/discovery/manifest_reader.dart) walks the root + every package reachable from `.dart_tool/package_config.json` for `lib/src/_testeador/*.testeador.manifest.json`; [lib/src/discovery/picker.dart](../../lib/src/discovery/picker.dart) flattens manifests into `DiscoveredCatalog`/`DiscoveredEntry` with identifiers assigned by the same [IdentifierNamer](../../lib/src/codegen/identifier_naming.dart) the aggregator uses (so picker identifiers always match the generated `TestInjector.<id>` getters); [lib/src/discovery/flow_emitter.dart](../../lib/src/discovery/flow_emitter.dart) renders via `renderTemplate`.
- **Template**: [lib/src/mcp/templates/injected_flow.dart](../../lib/src/mcp/templates/injected_flow.dart), registered in [templates/_index.dart](../../lib/src/mcp/templates/_index.dart). Emits `dart test` entrypoint with `Testeador(flows: [...]).registerWithDartTest()` wrapping a single `TestFlowLasting`/`TestFlowTransient` whose steps are `TestInjector.<id>` references. Empty tag set renders as `<String>{}` (typed) to avoid the `{}`→Map ambiguity.
- **Shared helper**: `_emit`/`_dryRun` lifted from scaffold_tools.dart into [lib/src/mcp/safe_write.dart](../../lib/src/mcp/safe_write.dart) so the CLI and the MCP scaffolding tools share the same "refuse to overwrite + honor dry_run" contract.
- **Tests**: [test/discovery/](../../test/discovery/) — 16/16 green (picker collision/filter/select, manifest_reader package_config traversal, flow_emitter rendering incl. empty tag set + override + transient kind).
- **E2E verified** in [example/pokebattle_serverpod/pokebattle_serverpod_server/](../../example/pokebattle_serverpod/pokebattle_serverpod_server/): `dart run testeador discover` lists 4 captured tests, `--pick … --pick … --out test/picked_flow_test.dart` writes a flow file, `dart test test/picked_flow_test.dart` → 2/2 green. Combined with the pre-existing injected_flow_test.dart and in_memory_store_test.dart: 10/10 green.

**Out of scope (decided up-front):** dynamic test names (the CLI reads codegen manifests, so anything the AST scanner already skips stays invisible). Future work could spawn `dart run` to harvest runtime names, but requires exposing `Registry.all()`.

---

**Previous focus: `TestInjector` codegen — first cut landed (2026-05-29, uncommitted).**

New feature: inject existing `package:test` `test()` bodies into `TestFlow`s by name/tag/regex/package, even from other dependency packages, via build_runner codegen. Plan: `~/.claude/plans/quiero-poder-agregar-a-sharded-lollipop.md`.

What's in:

- **Pure pipeline (8/8 tests green, see `test/codegen_pipeline_test.dart`):**
  - [lib/src/codegen/registry.dart](lib/src/codegen/registry.dart) — `CapturedTest` + `Registry` (`byFqId`, `byName`, `byTags`, `byRegExp`).
  - [lib/src/codegen/captured.dart](lib/src/codegen/captured.dart) — drop-in shim for `package:test` that captures `test()` / `group()` / `setUp` / `tearDown` instead of executing.
  - [lib/src/codegen/identifier_naming.dart](lib/src/codegen/identifier_naming.dart) — lowerCamelCase + diacritic folding + collision resolution.
  - [lib/src/codegen/scanner.dart](lib/src/codegen/scanner.dart) — AST visitor that extracts `test()` calls with group chain and tags.
  - [lib/src/codegen/transformer.dart](lib/src/codegen/transformer.dart) — copy + rewrite imports + rename `main()`.
  - [lib/src/codegen/aggregator.dart](lib/src/codegen/aggregator.dart) — emits `lib/test_injector.g.dart` as a self-contained library (NOT `part of`).
- **Builders + config:**
  - [lib/src/codegen/builder_factories.dart](lib/src/codegen/builder_factories.dart) — `captureBuilderFactory` (auto_apply: dependents) + `aggregatorBuilderFactory` (root-only).
  - [build.yaml](build.yaml) — declares both builders.
- **Public endpoints:** [lib/captured.dart](lib/captured.dart) (for transformed `*_test.dart` files), [lib/codegen.dart](lib/codegen.dart) (for the generated `test_injector.g.dart`).

Side effects of the work:

- `pubspec.yaml` bumped: added `build ^4.0.6`, `source_gen ^4.2.3`, `glob ^2.1.0`; dev: `build_runner ^2.15.0`, `build_test ^3.5.15`. **Note:** `analyzer` jumped 8 → 13 because `source_gen 4.x` requires it.
- [lib/src/mcp/suite_inspector.dart:340](lib/src/mcp/suite_inspector.dart#L340) needed a one-line fix for analyzer 13's `NamedExpression → NamedArgument` refactor.

### E2E validated via `example/inject_demo/`

A pure-Dart sample (`example/inject_demo/`, no Flutter dep) runs the full pipeline:

- `dart run build_runner build` → emits `lib/test_injector.g.dart` + the transformed `.dart_tool/build/generated/inject_demo/lib/src/_testeador/math_test.testeador.dart`.
- `dart run build_runner test` → **9/9 green**: the `TestFlowLasting` exercises static getter (`TestInjector.returnsSumOfTwoPositives`), `byTags('pure')`, and `byRegExp(RegExp('returns zero'))`; closures resolve against the original `add` / `multiply` identifiers; original `math_test.dart` continues to run standalone alongside the injected flow.

### E2E in `example/pokebattle_serverpod/pokebattle_serverpod_server/` (added 2026-05-29)

Second working sample, this time in a "real" Serverpod sub-package:

- Source: [test/in_memory_store_test.dart](../../example/pokebattle_serverpod/pokebattle_serverpod_server/test/in_memory_store_test.dart) — vanilla `group()` + 4 `test()` blocks covering `InMemoryStore` round-trip / listing / battle persistence.
- Generated: [lib/test_injector.g.dart](../../example/pokebattle_serverpod/pokebattle_serverpod_server/lib/test_injector.g.dart) with `TestInjector.roundTripsARegisteredUser`, `.returnsNullForAnUnknownEmail`, `.listsPlayersInInsertionOrder`, `.persistsAndRetrievesABattle`.
- Consumer: [test/injected_flow_test.dart](../../example/pokebattle_serverpod/pokebattle_serverpod_server/test/injected_flow_test.dart) — `Testeador(flows: [TestFlowLasting(... steps: [TestInjector.x, ...])]).registerWithDartTest()`. Plain `dart test test/injected_flow_test.dart` → 4/4 injected; combined with the standalone source it's 8/8.

Three changes were needed to make this work:

1. `pokebattle_serverpod_server` was pulled out of `resolution: workspace` (see [example/pokebattle_serverpod/pubspec.yaml](../../example/pokebattle_serverpod/pubspec.yaml) and the server's pubspec). Server resolves independently → analyzer 13, meta 1.18.2, source_gen 4.2.3, build_runner 2.15.0, build_test 3.x.
2. `testeador|capture`'s `build_to` was switched from `cache` → `source` in the root [build.yaml](../../build.yaml). Reason: plain `dart test` cannot read `.dart_tool/build/generated/...` because package_config.json doesn't map it, and `dart run build_runner test` requires `--force-aot` which was removed in Dart SDK 3.11. With `build_to: source` the transformed `lib/src/_testeador/*.testeador.dart` is a normal package asset. Consumers must `.gitignore` `lib/src/_testeador/` and `lib/test_injector.g.dart`.
3. The server's local [build.yaml](../../example/pokebattle_serverpod/pokebattle_serverpod_server/build.yaml) scopes the capture builder to `test/in_memory_store_test.dart` only. `test/integration/greeting_endpoint_test.dart` wraps its `test()` in serverpod_test's `withServerpod(...)`, which internally calls real `package:test`'s `group()` — that crashes when the registry runs `runCapture(...)` because it's outside a test runner.

The Flutter-based examples (`example/pokebattle_rest/`, `example/pokebattle_serverpod/pokebattle_serverpod_flutter/`) are still **blocked**: `flutter_test` pins `meta 1.17.0`, `analyzer 10+` requires `meta 1.18.0`. The workspace lockfile from 2026-05-23 still has the old resolution; anyone running `dart pub get` at the workspace root will hit the conflict. Resolutions remain: wait for Flutter, or pull the flutter sub-package out of `resolution: workspace` too.

---

**Previous focus (kept for context): Publication prep + two correctness fixes (2026-05-26, uncommitted), bumped to v0.3.0.**

- **CLI-mode assertions fixed.** `package:test`'s `expect` (and even `package:matcher`'s) call `TestHandle.current`, throwing `OutsideTestException` outside a runner — so flows asserted fine under `dart test` but crashed under `Testeador.run()` (the CLI/binary CI mode). testeador now ships its own synchronous `expect` in `lib/src/expectations.dart`, exposed via a dedicated `package:testeador/expect.dart` import (NOT the main barrel — re-exporting matcher's namespace there collides with `package:test` in runner files). Flows import both `testeador.dart` and `expect.dart`; they must NOT import `package:test`. This was caught by running the REST e2e through the MCP.
- **Tag forwarding fixed.** `registerWithDartTest()` now passes `flow.tags` to `group(..., tags:)` so `dart test --tags` filters like the CLI's `--include-tags`.
- **Publication metadata.** Added `CHANGELOG.md`, `.pubignore` (excludes `docs/`, `evidence/`, `.env*`, build dirs — also clears the "rename docs/ to doc/" warning), and `repository`/`homepage`/`issue_tracker`/`topics` in pubspec. `dart pub publish --dry-run` is clean except the expected "git dirty" warning. Still `publish_to: none` — flip to publish.
- **E2E evidence** under `evidence/e2e-rest/` (7/7 flows green in CLI mode, smoke green via `dart test`) and `evidence/mcp-e2e-sim/` (iOS simulator composite captured via the MCP `snapshot_fleet` tool).

**MCP server landed earlier this session (2026-05-26, uncommitted).** testeador now ships an MCP server that exposes every feature of the package to MCP clients. Implementation under `lib/src/mcp/`. Originally shipped as a standalone `testeador_mcp` executable; on 2026-05-29 it was folded into the unified `testeador` binary as the `mcp` subcommand (see Current Focus). `mcp_dart`, `analyzer`, `path`, and `meta` were promoted to `dependencies` (not dev) so `dart pub global activate testeador` can build the executable.

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
