# PRD: Testeador

Version 1.0 · Last updated 2026-04-28 · Applies to testeador v0.2.0+

## Summary

Testeador is a Dart package that orchestrates sequential integration test flows for contract testing between frontend and backend teams. Frontend contract tests run inside the backend CI pipeline, catching regressions (breaking API changes, field renames, response mismatches) before they merge. Tests run via `dart test` or compile to a standalone binary with no Dart SDK in CI.

- **Vision:** a single source of truth for API contracts, shared and tested by both pipelines.
- **Mission:** let backend devs run frontend contract tests in CI unchanged, catching regressions early and forcing proactive cross-team communication.

## Problem

When the backend renames fields, reshapes responses, or removes endpoints, the contract breaks — but the frontend only finds out in its own CI or in production, too late. Rewriting the tests with backend tooling defines the contract twice; the copies drift and pass while the real contract is broken. Mocks make it worse: a suite full of fakes passes even when the real backend would fail.

**Solution:** the contract is defined once, in the frontend's own tests; the backend runs them as-is against real APIs. Full narrative with diagrams: [PROBLEM.md](PROBLEM.md). Roadmap pains addressed: 2 (single source of truth), 3 (automatic propagation), 4 (proactive communication) — see [roadmap.md](../roadmap.md).

## Target Users

- **Backend Developer (CI consumer)** — runs frontend contract tests in CI. Success: merge auto-blocked on a contract break, with a cURL log to reproduce.
- **Frontend Test Author** — writes tests with frontend tools; they run in backend CI without changes. Success: write once, run everywhere, no adaptation.
- **QA / Platform Engineer** — integrates the suite into backend CI, filtering by tag. Success: compile once, run in any CI; cURL logs make failures trivial to reproduce.

## Goals & Non-Goals

**Goals:** frontend contract tests run in backend CI unchanged (G1); regressions reported with reproducing cURL (G2); sequential execution guarantees determinism (G3); publishable on pub.dev (G4); standalone binary runs without the Dart SDK (G5); all calls hit real APIs (G6); runs via both `dart test` and CLI (G7).

**Non-Goals:** mock/stub support; automatic rollback of transient flows (`TestFlowTransient` is a marker, rollback is TODO); concurrency within a flow; performance/load testing; UI/visual/mobile testing.

## Scope

**Current (v0.2.0) — implemented & tested:** `Actor`, `Fixture<T>`, `TestStep`, `TestFlowLasting`, `TestFlowTransient` (marker), `Testeador` (dual mode: `registerWithDartTest()` + `run(args)`), `CurlInterceptor` with header redaction, CLI filtering and options, Pokémon example against two real backends. Detail of what works lives in [memory-bank/05-progress.md](memory-bank/05-progress.md); class model in [architecture.md](architecture.md).

**Near-term (v1.0 candidate):** `TestFlowTransient` rollback (strategy TBD); pub.dev publication (blockers: API stability, docs, license); stable public API; persistent-state-across-flows example; improved error messages.

**Future (v2+):** see [roadmap.md](../roadmap.md) pains 5–7; auto contract docs (OpenAPI/GraphQL); latency assertions; visual regression; DB-specific rollback strategies.

## Key User Journeys

1. **Backend runs the FE suite in CI** — FE publishes the suite as a Dart package → BE adds it as a dependency and a `bin/run_tests.dart` entry point → CI compiles and runs → on break, fails with a cURL log → BE reproduces locally and coordinates the fix.
2. **FE writes a new contract test** — define an `Actor` (or reuse), a `Fixture` if needed, and a list of `TestStep`s capturing state via closure → return a `TestFlowLasting` → run locally via `dart test` → commit; BE auto-runs the same flow.
3. **Regression blocks a PR** — BE renames `userId → id` → BE CI runs the FE suite → a step expecting `userId` fails → cURL log shows the request/response/assertion → PR blocks (exit 1) → both teams rename together and merge.

## Functional Requirements

| ID | Requirement | Status |
| --- | --- | --- |
| FR-1 | Execute TestFlows of sequential TestSteps in declaration order | Implemented |
| FR-2 | Capture actors/repos/state via closure in `TestStep.action` | Implemented |
| FR-3 | Multi-actor scenarios with independent cURL logs | Implemented |
| FR-4 | `Fixture<T>` setup/teardown with typed context | Implemented |
| FR-5 | Record all HTTP calls as copy-pasteable cURL commands | Implemented |
| FR-6 | Header redaction (default: `authorization`, `cookie`) | Implemented |
| FR-7 | Dual execution: `dart test` integration + CLI binary | Implemented |
| FR-8 | CLI filtering by tags and flow names | Implemented |
| FR-9 | CLI options: verbose, fail-fast, exit-on-failure, show-curls, show-stack-traces | Implemented |
| FR-10 | `TestFlowLasting` — side effects persist | Implemented |
| FR-11 | `TestFlowTransient` — marker type (rollback TODO) | Marker only |
| FR-12 | Compile to standalone binary, no Dart SDK in CI | Implemented |
| FR-13 | No mocks — all HTTP calls to real APIs | By convention (not enforced) |

## Non-Functional Requirements

- **Execution:** sequential within a flow; each step waits for the prior (no race conditions).
- **HTTP:** no mocks; all calls to real APIs (staging, sandbox, public).
- **CI:** standalone binary works without the Dart SDK; portable to any CI that runs a binary.
- **Observability:** cURL log printed on failure (`--show-curls` default true); header redaction on by default (no secret leaks in logs).
- **Safety:** `Fixture.dispose()` guaranteed even on failure.
- **Platform:** Dart SDK `^3.11.0`; minimal deps (`dio`, `args`, `test`).

## Success Metrics

- Contract regressions caught pre-merge: >0 per quarter per active project.
- Time-to-detection: same day (in CI) vs. weeks (in production).
- Adoption: >1 backend team by v1.0.
- Pass rate: >95% (failures should be real contract breaks, not flakiness).
- DX: <30 min to write a first flow from scratch.

## Risks & Open Questions

- **`TestFlowTransient` rollback is complex** → deferred; enforce `TestFlowLasting` and gather usage data before picking a strategy (transaction-scope callback vs. `RollbackStrategy` interface vs. DB-specific).
- **Dependency on real external APIs** → flakiness if a public API is down; target staging environments under your control.
- **FE/BE drift** → tight version pinning and a shared versioning strategy.
- **Pub.dev blockers** → inventory API stability, license, docs early.
- Open: error-handling philosophy (typed exceptions? custom handlers?), fixture composition, CI integration examples (GH Actions/GitLab/Jenkins).

> Glossary and class signatures: [architecture.md](architecture.md).
