# Project Brief: Testeador

**Update this file when:** Project scope, name, or fundamental purpose changes.

---

## What Is This?

Testeador is a Dart package that orchestrates sequential integration test flows for contract testing. It allows frontend teams to write integration tests once and have them run in both frontend CI and backend CI, catching API contract breaks before they reach production.

## Core Function

- **Input:** Frontend integration test flows (TestFlowLasting/TestFlowTransient) and actors (user personas).
- **Process:** Execute flows sequentially; record all HTTP calls as cURL commands via interceptor.
- **Output:** Pass/fail status; on failure, print cURL log so developers can reproduce the exact request sequence.

## Version & Status

- **Current:** 0.2.0
- **Public API:** Stable; marked for v1.0 publication.
- **Dart SDK:** ^3.11.0
- **Publish to:** Currently `none`; roadmap includes pub.dev.

## Key Constraint

**No mocks.** All HTTP calls must go to real APIs (staging, sandbox, public). In-memory fakes are forbidden; they hide contract breaks.

## Execution Models

1. **Dart test mode:** `registerWithDartTest()` integrates with `package:test` for local development via `dart test`.
2. **CLI binary mode:** `run(args)` parses CLI flags; compiles to standalone binary with `dart compile exe` (no Dart SDK needed in CI).

## Success Criterion

Contract regressions (field name changes, response shape changes, endpoint removals) are detected in backend CI, not in production.
