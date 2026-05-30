# Progress: What Works, What's Left

**Update this file when:** A feature reaches "done", a blocker is resolved, or status changes materially.

---

## What Works (v0.2.0)

### Core Classes
- [x] **Actor** — Abstract class; subclasses provide configured Dio instance with custom auth/headers.
- [x] **CurlInterceptor** — Dio interceptor; records all requests as cURL commands; header redaction.
- [x] **Fixture<T>** — Generic setup/teardown with typed context; load() and dispose() lifecycle.
- [x] **TestStep** — Named actions with zero-argument async callbacks; closure capture of context.
- [x] **TestFlowLasting** — Flows whose side effects persist (seeding, write-path tests).
- [x] **TestFlowTransient** — Marker type (rollback not implemented; behaves as Lasting).
- [x] **TesteadorOptions** — Value class holding configuration (tags, flows, verbose, etc.).
- [x] **Testeador** — Orchestrator with dual execution modes.

### Execution Modes
- [x] **registerWithDartTest()** — Integrates flows as group()/test() blocks with package:test.
- [x] **run(args)** — CLI mode with argument parsing, sequential execution, exit codes.

### Features
- [x] Sequential execution within flows (no concurrency).
- [x] Multi-actor support with independent cURL logs.
- [x] Fixture lifecycle (setup before steps, teardown in finally block).
- [x] CLI filtering by tags (--include-tags, --exclude-tags).
- [x] CLI filtering by flow name (--include-flows, --exclude-flows).
- [x] Verbose logging (--verbose flag).
- [x] Fail-fast behavior (--fail-fast, default true).
- [x] Exit code control (--exit-on-failure, default true).
- [x] cURL log display on failure (--show-curls, default true).
- [x] Stack trace display (--show-stack-traces, default false).
- [x] Header redaction (default: authorization, cookie; customizable per actor).
- [x] Standalone binary compilation (dart compile exe).

### Example (REST)
- [x] Pokémon battle scenario with two actors (Firesh, Watersh).
- [x] Three flows (fire team registration, water team registration, battle challenge).
- [x] Integration with two real HTTP backends (PokéAPI, restful-api.dev).
- [x] No mocks; all HTTP calls are real.

### Example (Serverpod streaming)
- [x] Mini Serverpod project at `example/pokebattle_serverpod/` (server + client + flutter).
- [x] Streaming endpoints fan-out via `session.messages` (MessageCentral): `playerAdded`, `battleAdded`, `battleUpdates`.
- [x] Flutter UI mirrors the REST example screens; lobby auto-updates with a `● Live` chip.
- [x] Patrol agent flows (`register_and_land_in_lobby`, `register_player`, `create_battle`, `accept_battle`).
- [x] testeador smoke flow drives Patrol on two devices in parallel and captures `evidence/<label>/composite.png` for each step.

### Multi-device evidence (lib/src/multidev/)
- [x] `TargetDevice` (`AndroidEmulator`, `IosSimulator`) abstraction with boot/shutdown/screenshot primitives.
- [x] `DeviceFleet` orchestrator with `snapshot`, `snapshotComposite`, `runPatrolAcross`, `runPatrolOn`.
- [x] `FlutterActor extends Actor` binds an HTTP persona to a device.
- [x] `PatrolRunner` host-side subprocess wrapper.
- [x] `ScreenshotComposer.sideBySide` produces a single horizontal PNG with per-device header strips (the canonical AI-review artifact).
- [x] CLI `bin/snapshot_fleet.dart` for ad-hoc evidence capture.

### MCP server (lib/src/mcp/, bin/testeador.dart `mcp` subcommand)

- [x] `testeador mcp` subcommand built on `mcp_dart` (stdio transport), exposing all package features to MCP clients.
- [x] `WorkspaceConfig` resolves the target project via `TESTEADOR_PROJECT_ROOT` or CWD walk-up (is/depends-on testeador).
- [x] Introspection tools: `list_suites`, `inspect_suite` (analyzer AST walk, resolves flows in imported `*_flow.dart`), `list_tags`, `dry_run_suite` (reuses public `filterFlows`).
- [x] Execution tools: `run_suite_cli`, `run_suite_dart_test`, `compile_suite_exe` — all support `execute: false` command-only mode; cURL logs and pass/fail counts parsed from output.
- [x] Scaffolding tools: `scaffold_actor/fixture/flow/suite_runner/dart_test_main` — all support `dry_run`; refuse to overwrite existing files.
- [x] Multidev tools (gated by `TESTEADOR_MCP_ENABLE_MULTIDEV=1`): `list_devices`, `boot_fleet`, `shutdown_fleet`, `snapshot_fleet`, `run_patrol_fleet`.
- [x] Resources (`testeador://templates/*`, `testeador://docs/*`) and prompts (`scaffold_suite`, `diagnose_failure`).
- [x] Tests under `test/mcp/` (curl parser, process runner, suite inspector golden against pokebattle_rest, template syntax validation). All passing.
- [x] `.mcp.json` wired with a `testeador` server entry.

### Assertions & dual-mode consistency (v0.3.0)
- [x] `lib/src/expectations.dart` — zone-independent `expect` + re-exported matchers, surfaced via `package:testeador/expect.dart`. Works in both `run()` (CLI) and `registerWithDartTest()`. Fixes the `OutsideTestException` crash in CLI mode.
- [x] `registerWithDartTest()` forwards `flow.tags` to `group(tags:)` so `dart test --tags` matches the CLI's `--include-tags`.
- [x] Example flows migrated off `package:test` assertions onto `package:testeador/expect.dart`.

### Publication readiness (v0.3.0)
- [x] `CHANGELOG.md`, `repository`/`homepage`/`issue_tracker`/`topics` in pubspec, `.pubignore`. `dart pub publish --dry-run` clean (only the expected git-dirty warning). Still `publish_to: none`.

### Documentation
- [x] README.md (usage guide, quick start, CLI reference, MCP server section).
- [x] docs/architecture.md (full technical spec with class diagrams).
- [x] docs/PROBLEM.md (problem narrative in Spanish).
- [x] roadmap.md (pains 2-7 driving evolution).
- [x] example/pokebattle_rest/README.md (REST example overview).

## What Works (v0.3.0 in-flight — uncommitted 2026-05-29)

### `TestInjector` Codegen (pure pipeline)

- [x] **`Registry` + `CapturedTest`** — runtime types in [lib/src/codegen/registry.dart](../../lib/src/codegen/registry.dart).
- [x] **`captured.dart` shim** — drop-in for `package:test` that captures lifecycle hooks instead of executing.
- [x] **AST scanner** — extracts `test()` calls with group chain and tags; warns on non-literal names.
- [x] **Source transformer** — rewrites `package:test` → shim, relative `lib/` imports → `package:<pkg>/...`, renames `main()` to `_testeadorCapture$<hash>`.
- [x] **Identifier namer** — lowerCamelCase + Latin diacritic folding + 4-step collision resolution.
- [x] **Aggregator** — emits self-contained `lib/test_injector.g.dart` with one static getter per discovered test plus dynamic `byName` / `byTags` / `byRegExp`.
- [x] **Builder factories + build.yaml** — `capture` (auto_apply: dependents) + `aggregator` (root_package).
- [x] **Pipeline tests** — 8/8 green in [test/codegen_pipeline_test.dart](../../test/codegen_pipeline_test.dart).

### E2E

- [x] **`build_runner build` end-to-end** — verified in [example/inject_demo/](../../example/inject_demo/). `dart run build_runner test` → 9/9 green; the flow exercises static getters + `byTags` + `byRegExp` and the closures resolve correctly against their original imports.
- [x] **End-to-end in `pokebattle_serverpod_server`** — [test/in_memory_store_test.dart](../../example/pokebattle_serverpod/pokebattle_serverpod_server/test/in_memory_store_test.dart) is captured and the 4 `test()`s land as `TestStep`s of a `TestFlowLasting` in [test/injected_flow_test.dart](../../example/pokebattle_serverpod/pokebattle_serverpod_server/test/injected_flow_test.dart). Plain `dart test` → 4/4 (or 8/8 combined with the source file). Required dropping the server from `resolution: workspace`, switching `testeador|capture` to `build_to: source`, and scoping the capture builder to skip the serverpod-test-wrapped integration tree.

### Discover-and-pick (CLI + MCP)

- [x] **CLI `dart run testeador discover`** — subcommand of the unified [bin/testeador.dart](../../bin/testeador.dart) entrypoint, body in [lib/src/discovery/cli.dart](../../lib/src/discovery/cli.dart). Lists captured tests (text/JSON), filters (`--tag`/`--pattern`/`--package-name`), picks (`--pick`), and emits a `TestFlow` entrypoint via the `injected_flow` template (or `--print` to stdout, `--dry-run` to preview). The single `testeador` executable is declared in `executables:` of [pubspec.yaml](../../pubspec.yaml).
- [x] **MCP tool `discover_tests`** — [lib/src/mcp/tools/discovery_tools.dart](../../lib/src/mcp/tools/discovery_tools.dart). Subprocess-wraps the CLI so the implementation lives in one place. Wired through [lib/src/mcp/tools/tools.dart](../../lib/src/mcp/tools/tools.dart).
- [x] **Discovery library** — [lib/src/discovery/](../../lib/src/discovery/): `manifest_reader.dart` walks the root package plus every entry of `.dart_tool/package_config.json` for `lib/src/_testeador/*.testeador.manifest.json`; `picker.dart` flattens into `DiscoveredCatalog` with identifiers assigned via the same `IdentifierNamer` the aggregator uses (so picker identifiers match `TestInjector.<id>` exactly); `flow_emitter.dart` renders via the new `injected_flow` template.
- [x] **Shared `safeWrite`** — [lib/src/mcp/safe_write.dart](../../lib/src/mcp/safe_write.dart). Extracted from the duplicate `_emit` logic in scaffold_tools.dart; CLI + MCP scaffolding tools share the "refuse to overwrite + honor dry-run" contract.
- [x] **Unit tests** — 16/16 green in [test/discovery/](../../test/discovery/) (catalog flatten/filter/select, manifest_reader package_config traversal, flow_emitter rendering across lasting/transient/empty-tag/override cases).
- [x] **E2E verified** — `dart run testeador discover` lists 4 captured tests in `pokebattle_serverpod_server`; picking 2 of them and `dart test test/picked_flow_test.dart` → 2/2 green.

### Pending

- [ ] **True cross-package injection** — both samples above capture and inject in the same package. The next milestone is capturing a `test()` from `pokebattle_serverpod_server` and injecting it from a flow declared in `pokebattle_serverpod_client` (or any other dependent package) to validate `auto_apply: dependents` across the graph.
- [ ] **Flutter-host workaround** — `example/pokebattle_rest/` and `example/pokebattle_serverpod/pokebattle_serverpod_flutter/` cannot run build_runner yet (`flutter_test` pins `meta 1.17.0`, analyzer 10+ requires `meta 1.18.0`). Either wait on the Flutter SDK, document a `dependency_overrides` recipe, or pull the Flutter sub-package out of `resolution: workspace`.

## What's Unimplemented / TODO

### High Priority (Candidate for v1.0)

- [ ] **TestFlowTransient rollback** — Currently a marker type with no-op behavior. Real rollback is TODO. Candidate strategies:
  - (a) Add a `RollbackStrategy` interface on Fixture; implement for different database types.
  - (b) Add a transaction scope callback on Fixture (e.g., `Future<T> load(Transactional txn)`).
  - (c) Database-specific mechanisms (e.g., SQL SAVEPOINT for Postgres).
  - **Decision:** Deferred pending real-world usage patterns from example app and team feedback.

- [ ] **Pub.dev publication** — Currently `publish_to: none`. Blockers likely include:
  - API stability assessment (compare 0.1.0 → 0.2.0; ensure no more breaking changes expected).
  - License clarity (MIT is mentioned in README; confirm in LICENSE file).
  - Code of Conduct and contribution guidelines.
  - Documentation completeness (README, API docs, examples).
  - **Decision:** Inventory blockers and resolve by v1.0 target.

- [ ] **Improved error messages** — Currently, test failures print the exception and cURL log. Could be richer:
  - Suggest common mistakes (e.g., "Did you forget to pass actors to Testeador()?").
  - Better diagnostics for mocking attempts.
  - Clearer formatting of cURL commands (syntax highlighting in some CI systems).

### Medium Priority (v1.x / Future)

- [ ] **Multiple fixture support** — Currently one Fixture per flow. Could allow composition or chaining.

- [ ] **Custom error handlers** — Allow flows to define error recovery logic or custom logging.

- [ ] **Performance assertions** — Support latency thresholds on HTTP calls (e.g., `expect(duration, lessThan(1.second))`).

- [ ] **OpenAPI / GraphQL documentation** — Auto-generate contract documentation from flows.

- [ ] **CI integration examples** — GitHub Actions, GitLab CI, Jenkins snippets.

- [ ] **Fixture replay / debugging** — Tools to record and replay a fixture's HTTP calls for offline debugging.

### Low Priority / Out of Scope (v2+)

- [ ] **Visual regression testing** — Testeador is for HTTP contracts; visual testing is separate.
- [ ] **Performance profiling** — Build profiling dashboards for latency trends.
- [ ] **Distributed tracing integration** — Hook into OpenTelemetry or similar.
- [ ] **Load testing** — Testeador is for correctness, not scale.

## Known Issues & Workarounds

### Issue: TestFlowTransient Has No Rollback
**Status:** Open (design decision deferred)  
**Impact:** Read-only flows must use TestFlowLasting; side effects persist even for transient scenarios.  
**Workaround:** Document which flows are logically read-only (for developer communication) even if side effects persist.  
**Resolution path:** Gather usage data from production runs; pick a rollback strategy; implement for v1.0.

### Issue: External API Dependency
**Status:** Known limitation  
**Impact:** Tests fail if PokéAPI or restful-api.dev are unavailable.  
**Workaround:** Use staging/sandbox APIs under your control in production CI.  
**Resolution path:** Document as a requirement; provide runbook for teams to host staging versions.

### Issue: Closure Capture Complexity
**Status:** Design choice (intentional)  
**Impact:** Flows with many steps capture a lot of state; can be hard to trace.  
**Workaround:** Keep flows focused (one logical scenario per flow); use clear variable names; add comments.  
**Resolution path:** Provide better examples; improve error messages to reference captured variables.

## Version History

| Version | Date | Status | Key Changes |
|---------|------|--------|-------------|
| 0.1.0 | TBD | Archived | Initial implementation (see git history). |
| 0.2.0 | Current | Stable | Full dual-mode execution (dart test + CLI); Pokémon example; no breaking changes expected before v1.0. |
| 1.0 | TBD | Candidate | Rollback for TestFlowTransient; pub.dev publication; API finalized. |

## Definition of Done Checklist

For a feature to move from TODO to Done:

- [ ] Code is implemented and tested.
- [ ] Public API is documented in code (doc comments).
- [ ] Example usage is demonstrated (in example/ or in docs/).
- [ ] No breaking changes to existing code (or version bumped to major).
- [ ] Related memory-bank files are updated.
- [ ] Blockers or open questions are recorded.

## Test Coverage Status

- **testeador lib tests:** TBD (verify with `dart test lib/src/`).
- **Example app tests:** Working (runs via `dart run example/pokebattle_rest/bin/run_tests.dart`).
- **Integration with dart test:** Verified (example/pokebattle_rest/bin/run_tests.dart can be modified to use registerWithDartTest).

## Evolution Roadmap

See [roadmap.md](../roadmap.md) for broader product evolution (Pains 2-7). This file tracks implementation progress; that file tracks problem-driven roadmap.
