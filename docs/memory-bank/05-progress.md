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

### Example
- [x] Pokémon battle scenario with two actors (Firesh, Watersh).
- [x] Three flows (fire team registration, water team registration, battle challenge).
- [x] Integration with two real HTTP backends (PokéAPI, restful-api.dev).
- [x] No mocks; all HTTP calls are real.

### Documentation
- [x] README.md (usage guide, quick start, CLI reference).
- [x] docs/architecture.md (full technical spec with class diagrams).
- [x] docs/PROBLEM.md (problem narrative in Spanish).
- [x] roadmap.md (pains 2-7 driving evolution).
- [x] example/README.md (example overview).

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
- **Example app tests:** Working (runs via `dart run example/bin/run_tests.dart`).
- **Integration with dart test:** Verified (example/bin/run_tests.dart can be modified to use registerWithDartTest).

## Evolution Roadmap

See [roadmap.md](../roadmap.md) for broader product evolution (Pains 2-7). This file tracks implementation progress; that file tracks problem-driven roadmap.
