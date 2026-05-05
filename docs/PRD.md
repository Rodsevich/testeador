# Product Requirements Document: Testeador

**Document Status**  
Version: 1.0  
Last Updated: 2026-04-28  
Owner: TBD  
Applies To: testeador package v0.2.0 and forward

---

## Executive Summary

Testeador is a Dart package that orchestrates sequential integration test flows for contract testing between frontend and backend teams. It enables frontend integration tests to run inside the backend CI pipeline, catching contract regressions (breaking API changes, field name changes, response structure mismatches) before they merge to main. Tests run via `dart test` or compile to a standalone binary with no Dart SDK dependency in CI. This document defines the product vision, scope, and requirements for testeador v1.0 and beyond.

---

## Vision & Mission

**Vision:** A single source of truth for API contracts, shared and tested by both frontend and backend pipelines.

**Mission:** Enable backend developers to run frontend contract tests in CI without modifying the frontend test code, catching contract regressions early and forcing proactive communication between teams.

---

## Problem Statement

### The Silent Contract Break

When backend developers rename fields, change response shapes, or remove endpoints, the contract with the frontend is broken. Frontend code cannot detect the break until:
- The frontend runs its own tests (which fail reactively in FE CI).
- The code deploys to production (where the frontend fails in the user's app).

By then, damage is done. Data has been lost, bugs are in production, and the teams are in reactive damage control.

### Why Duplication Is Wrong

If the backend team rewrite the contract tests with their own tools (ad-hoc HTTP tests, validation scripts), the contract is now defined twice: once in frontend tests, once in backend tests. Both must be kept in sync. Over time, they diverge. Tests pass; the real contract is broken. A false sense of security.

**Solution:** The contract is defined once, in the frontend's own test code. The backend runs it as-is, with no adaptation.

### Why Mocks Make It Worse

In-memory fakes and mock objects allow tests to pass even when the real backend would fail. A contract test suite full of mocks is a hallucination: the tests pass, but the contract is broken. Testeador solves this by requiring all HTTP calls to go to real APIs (staging, sandbox, or public test APIs).

### Key Pains Addressed

- **Pain 2 (Roadmap):** Single source of truth for contracts. Frontend tests are the contract; backend runs them unchanged.
- **Pain 3 (Roadmap):** Manual adaptation of code on contract changes. Propagation is automatic; the backend just re-runs the existing tests.
- **Pain 4 (Roadmap):** Reactive communication between teams. A backend PR that breaks frontend tests now blocks the merge, forcing proactive synchronization.

---

## Target Users & Personas

### 1. Backend Developer (CI Consumer)
- **Need:** Run frontend contract tests in CI to validate that API changes don't break consumers.
- **Pain:** Currently, contract breaks are discovered in FE CI or production, not in BE pipeline.
- **Success:** Merge blocked automatically when a change breaks a contract; cURL log provided to reproduce the issue.

### 2. Frontend Test Author
- **Need:** Write integration tests using frontend tools and patterns, then have them run in backend CI without changes.
- **Pain:** Duplicating test code or adapting tests for backend tools defeats the purpose of a single source of truth.
- **Success:** Write once, run everywhere (FE CI and BE CI) with no adaptation.

### 3. QA / Platform Engineer (Pipeline Configurator)
- **Need:** Integrate the contract test suite into the backend CI pipeline, with filtering by tag and easy debugging.
- **Pain:** Setting up cross-team test suites is complex; understanding failures requires full HTTP logs.
- **Success:** Compile once, run in any CI system; cURL logs make failure reproduction trivial.

---

## Value Proposition

| Benefit | For Whom | Impact |
|---------|----------|--------|
| Catch contract breaks before merge | Backend dev | Prevent production incidents; reduce hotfixes |
| No test code duplication | Frontend & backend | Single source of truth; no drift; less maintenance |
| Real HTTP calls only | QA / Test author | True confidence in contract; mocks can't hide breaks |
| Standalone binary | CI engineer | No Dart SDK needed in CI; works in any environment |
| Closure-based context passing | Test author | Natural Dart idiom; no boilerplate; easy to read flows |
| Per-actor cURL logs | Backend dev | Attributable failure logs; multi-user scenarios supported |
| Fixture lifecycle management | Test author | Setup/teardown is declarative; cleanup guaranteed even on failure |

---

## Goals & Non-Goals

### Goals (Measurable)

- **G1:** Frontend contract tests can be executed in backend CI without modification.
- **G2:** Contract regressions are detected and reported with reproducing cURL commands.
- **G3:** Flows execute sequentially, guaranteeing no race conditions or non-determinism from concurrency.
- **G4:** The package can be published on pub.dev and imported as a normal Dart dependency.
- **G5:** A standalone binary can be compiled and run in any CI environment with no Dart SDK.
- **G6:** All HTTP calls are made to real APIs; mocks are not supported.
- **G7:** Tests run both via `dart test` (for local development) and as CLI (for CI).

### Non-Goals

- Mock/stub support. Testeador is for integration tests only.
- Automatic rollback of transient (read-only) flows. `TestFlowTransient` is a marker type; rollback is TODO.
- Parallel or concurrent execution within a flow. Sequential only.
- Built-in performance testing or load testing. Testeador is for correctness, not scale.
- UI/visual testing or mobile-specific testing. HTTP contracts only.

---

## Scope

### Current (v0.2.0)

**What works:**

- `Actor` — subclass to define a named persona with a configured `Dio` instance.
- `Fixture<T>` — generic setup/teardown with typed context captured by steps via closure.
- `TestStep` — named actions with zero-argument async callbacks.
- `TestFlowLasting` — flows whose side effects intentionally persist.
- `TestFlowTransient` — marker type (no rollback; behaves as Lasting).
- `Testeador` — dual-mode orchestrator:
  - `registerWithDartTest()` — integrates with `package:test` for `dart test` runs.
  - `run(args)` — CLI mode with filtering (tags, flow names) and options (verbose, fail-fast, cURL display, stack traces).
- `CurlInterceptor` — records all HTTP requests as copy-pasteable cURL commands.
- Header redaction — default redacts `authorization` and `cookie`; customizable per actor.
- Pokémon example — two actors, three flows, two real HTTP backends (no mocks).

**Tested:**
- Flows execute sequentially.
- Actor cURL logs are cleared before each flow and printed on failure.
- Fixture setup/teardown are called correctly.
- CLI parsing (tags, flow filtering, options).
- Both `dart test` and CLI modes work.

### Near-term (v1.0 Candidate)

**Likely additions (not yet committed):**

- `TestFlowTransient` rollback — currently TODO. Candidate strategies: (1) transaction scope callback; (2) `RollbackStrategy` interface. Decision pending real-world usage data.
- Publication on pub.dev — currently `publish_to: none` in pubspec. Blockers: public API stability, documentation completeness, licensing clarity.
- Stable public API — audit exports, finalize error handling, ensure no breaking changes in next minor releases.
- Example with persistent state across multiple flows — demonstrate how lasting flows accumulate data for later tests.
- Improved error messages — better diagnostics for common mistakes (e.g., forgetting to pass actors, mocking by accident).

### Future / Out of Scope (v2+)

- Derived from `roadmap.md` Pains 5, 6, 7: multidisciplinary feature development process, standardized user story format, PRD-driven AI context.
- Automatic contract documentation generation (OpenAPI, GraphQL schema).
- Performance/latency assertions on HTTP calls.
- Visual regression testing.
- Database-specific rollback strategies (e.g., transaction-based for PostgreSQL).

---

## Key User Journeys

### Journey 1: Backend Dev Runs FE Contract Suite in CI

```
1. Frontend team publishes their contract test suite as a Dart package (git ref or pub.dev).
2. Backend team adds it as a dependency.
3. Backend creates a bin/run_tests.dart entry point, registering their Testeador instance.
4. CI job compiles and runs: dart compile exe bin/run_tests.dart -o test_runner && ./test_runner
5. On contract break, tests fail with cURL log showing exact requests.
6. Backend dev reproduces locally by copy-pasting the cURL command.
7. Backend dev fixes the breaking change and coordinates with frontend team.
```

### Journey 2: Frontend Dev Writes a New Contract Test

```
1. Frontend dev creates a new test/flows/my_flow.dart file.
2. Defines an Actor subclass (or reuses existing) with their Dio config.
3. Defines a Fixture if setup is needed.
4. Defines a list of TestSteps capturing actors, repos, shared state via closure.
5. Returns a TestFlowLasting with name, steps, fixture, tags.
6. Runs locally via dart test (which calls registerWithDartTest).
7. Commits. Backend team auto-runs the same flow in their CI.
```

### Journey 3: Contract Regression Blocks PR

```
1. Backend dev merges a change to field name: userId → id.
2. Backend CI compiles and runs the frontend contract suite.
3. TestFlowLasting fails because a step expects userId.
4. CI prints cURL log: shows the request, response with id, and the assertion that failed.
5. PR blocks (exit code 1).
6. Backend dev and frontend dev synchronize: both rename at the same time.
7. Both PRs merge together (or one waits for the other).
8. Contract is no longer broken.
```

---

## Functional Requirements

| ID | Requirement | Status | Notes |
|---|---|---|---|
| FR-1 | Define and execute TestFlows composed of sequential TestSteps | Implemented v0.2.0 | Steps run in declaration order, guaranteed. |
| FR-2 | Capture actors, repos, and shared state via closure in TestStep.action | Implemented v0.2.0 | Zero-argument action callback; no generic type parameters. |
| FR-3 | Support multi-actor scenarios with independent cURL logs | Implemented v0.2.0 | Each Actor has its own CurlInterceptor; logs are cleared and printed per-actor. |
| FR-4 | Fixture setup/teardown with typed context generic over T | Implemented v0.2.0 | load() before steps, dispose(T) after in finally block. |
| FR-5 | Record all HTTP calls as copy-pasteable cURL commands | Implemented v0.2.0 | CurlInterceptor overrides onRequest; cURLs printed on failure. |
| FR-6 | Header redaction (default: authorization, cookie) | Implemented v0.2.0 | Opt-out; customizable per actor. |
| FR-7 | Dual execution: dart test integration and CLI binary | Implemented v0.2.0 | registerWithDartTest() + run(args). |
| FR-8 | CLI filtering by tags and flow names | Implemented v0.2.0 | --include-tags, --exclude-tags, --include-flows, --exclude-flows. |
| FR-9 | CLI options: verbose, fail-fast, exit-on-failure, show-curls, show-stack-traces | Implemented v0.2.0 | Parsed from --flags; defaults sensible for CI. |
| FR-10 | TestFlowLasting — flows whose side effects persist | Implemented v0.2.0 | Concrete subclass; used for seeding, write-path tests. |
| FR-11 | TestFlowTransient — marker type (TODO: implement rollback) | Marker only in v0.2.0 | No-op; intended for read-only flows once rollback is implemented. |
| FR-12 | Compile to standalone binary with no Dart SDK dependency in CI | Implemented v0.2.0 | dart compile exe works; binary runs independently. |
| FR-13 | No mocks — all HTTP calls must go to real APIs | Not enforced, by convention | Fixture lifecycle and multi-flow setup patterns make mocks unnecessary and actively discourage them. |

---

## Non-Functional Requirements

| Category | Requirement | Rationale |
|----------|---|---|
| **Execution** | Sequential execution within a flow | Eliminate race conditions and non-determinism. |
| **Execution** | No concurrency within a flow; each step waits for prior step to complete | Stepping is ordered; shared state captured via closure must be safe. |
| **HTTP** | No mocks; all calls to real APIs (staging, sandbox, or public) | Mocks hide contract breaks; integration tests must exercise the real backend. |
| **CI** | Standalone binary (dart compile exe) works without Dart SDK | Enables deployment to any CI environment; no SDK installation overhead. |
| **Observability** | cURL log printed on failure (with --show-curls default true) | Backend devs must be able to copy-paste and reproduce. |
| **Observability** | Header redaction enabled by default (auth, cookie) | CI logs must not leak secrets. |
| **Safety** | Fixture.dispose() guaranteed even on failure | Resource cleanup is reliable; no leaks. |
| **Portability** | Works in any CI system that can run a binary | No CI-specific plugins or setup. |
| **Dart** | Dart SDK ^3.11.0 | Latest stable; use modern Dart features. |
| **Dependencies** | Minimal; only dio, args, test as transitive | Keep dependency tree small; reduce supply-chain risk. |

---

## Success Metrics (Proposed)

| Metric | Definition | Target | Notes |
|---|---|---|---|
| Contract regressions caught pre-merge | Count of contract breaks detected by backend CI before merge | > 0 per quarter per active project | Validates the core value. |
| Time-to-detection | Days between contract change and detection | Same day (in CI) vs. weeks (in production) | Target: detect in backend CI pipeline. |
| Adoption | Number of backend projects integrating the suite | > 1 team by v1.0 | Signals product-market fit. |
| Test pass rate | % of flows passing in CI each run | > 95% (expected; failures are contract breaks, not flakiness) | Sequential execution and real APIs should minimize flakiness. |
| Developer experience | Ease of writing a new flow (feedback: time to first test) | < 30 min from scratch | If this is long, docs/patterns need improvement. |

---

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| TestFlowTransient rollback is complex | Tests require manual cleanup; side effects leak between flows | Medium | Defer rollback; enforce TestFlowLasting for now. Gather usage data before implementing. |
| Pub.dev publication blockers | Package cannot be imported from central registry; adoption stalls | Low | Identify blockers early (API stability, license, CoC); address in v1.0. |
| Drift: FE test code diverges from BE runtime | Tests are outdated; FE tests fail at publishing time, not in BE CI | Medium | Tight version pinning; shared versioning strategy between FE and BE teams. |
| Dependency on real external APIs | Flakiness if PokéAPI or restful-api.dev is down; tests fail outside of your control | Medium | Tests should target staging environments, not prod. Testeador enables this via Actor configuration. Document this as a requirement. |
| Closure-capture complexity | Steps capture a lot of state; harder to debug than explicit parameters | Low | Provide clear examples in docs. Error messages should reference closures. |
| Binary size after dart compile exe | Large binary size may slow CI deployment | Low | Monitor in real usage. Dart compile is generally efficient. |

---

## Open Questions

The following are known TODOs and decisions deferred pending real-world usage or team input:

1. **TestFlowTransient rollback strategy:** Should rollback use (a) transaction scope callbacks on Fixture, (b) a `RollbackStrategy` interface, (c) database-specific mechanisms? Decision pending usage patterns and team feedback.

2. **Pub.dev publication:** What are the exact blockers? (API stability? License choice? Code of Conduct? Documentation standards?) Inventory and plan for v1.0.

3. **Error handling philosophy:** Currently, test failures are caught and logged. Should exceptions be typed? Should we support custom error handlers?

4. **Fixture composition:** Can one Fixture depend on the output of another? Should TestFlowTransient fixtures be read-only? Edge cases unclear until real usage emerges.

5. **CI integration examples:** Should we provide GitHub Actions, GitLab CI, Jenkins examples? Or just the binary interface?

---

## Glossary

- **Actor:** An abstract class representing a user persona. Subclasses provide a named `Dio` instance with pre-configured base URL, auth headers, etc.
- **CurlInterceptor:** A `Dio` interceptor that records outgoing HTTP requests as copy-pasteable cURL commands.
- **Fixture<T>:** An abstract generic class for setup/teardown. Subclasses implement `load()` (called before steps) and optionally `dispose(T)` (called after, even on failure).
- **TestStep:** A single named action within a flow. Has a zero-argument async callback (`action`) that captures actors, repos, and shared state via closure.
- **TestFlow:** Abstract base class for a named, ordered sequence of TestSteps. Can have an optional Fixture and a set of tags for filtering.
- **TestFlowLasting:** Concrete subclass of TestFlow; side effects intentionally persist (seeding, write-path tests).
- **TestFlowTransient:** Concrete subclass of TestFlow; marker type intended for read-only flows (rollback TODO, currently behaves as Lasting).
- **Testeador:** Top-level orchestrator. Executes flows sequentially via two modes: `registerWithDartTest()` (dart test) or `run(args)` (CLI binary).
- **Contract test:** An integration test that validates the HTTP contract (request/response shapes, field names, status codes) between a backend and its consumers (frontend apps).
- **Sequential execution:** Flows and steps run one after another, in declaration order. No concurrency within a flow.
- **No mocks:** Testeador is for integration tests; all HTTP calls must go to real APIs (staging, sandbox, or public test APIs). In-memory fakes are not supported.
- **Closure capture:** TestStep.action is a zero-argument function; context (actors, repos, shared state) is captured from the enclosing scope at the time the step is defined.
