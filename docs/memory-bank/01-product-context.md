# Product Context: Why Testeador Exists

**Update this file when:** Problem statement, user needs, or value proposition changes.

---

## The Problem

Frontend teams write integration tests to validate the API contracts the backend exposes: field names, response shapes, endpoint availability. Those tests only run in frontend CI. If a backend developer breaks the contract (renames a field, changes a response), the frontend doesn't discover the break until:

1. Frontend CI fails reactively (data already lost).
2. The code reaches production and users hit the broken contract.

This is a silent, reactive failure mode. By the time anyone notices, the damage is done.

## Why Single Source of Truth Matters

If the backend team rewrites the contract tests with their own tools (ad-hoc HTTP tests, scripts), the contract is now defined twice:
- Frontend: in their test code.
- Backend: in their test code.

Over time, these diverge. The tests pass; the real contract is broken. False confidence.

**Solution:** Contract is defined once, in the frontend's own tests. Backend runs them unchanged.

## Why No Mocks

In-memory fakes and mocks allow tests to pass even when the real backend would fail. A test suite full of mocks is a hallucination — tests pass, contract is broken.

Testeador forbids mocks. All HTTP calls go to real APIs (staging, sandbox, public test APIs).

## User Needs

### Backend Developer
- **Need:** Detect contract breaks in CI, not production.
- **Success:** Merge blocked automatically; cURL log provided to reproduce the issue.

### Frontend Test Author
- **Need:** Write tests once; have them run in both FE and BE CI unchanged.
- **Success:** No adaptation, no duplication, single source of truth.

### QA / Platform Engineer
- **Need:** Easy integration into backend CI; clear failure diagnostics.
- **Success:** Compile once; run in any CI; cURL logs make debugging trivial.

## Product Goals

1. Contract breaks detected and reported with reproducing cURL commands.
2. Frontend test code runs unchanged in backend CI.
3. Sequential execution guarantees determinism and no race conditions.
4. Fixture lifecycle (setup/teardown) is declarative and reliable.
5. HTTP observability: every request is recorded and visible on failure.

## Related Pains (From Roadmap)

- **Pain 2:** Unique source of truth for contracts.
- **Pain 3:** Automatic propagation of contract changes (no manual adaptation).
- **Pain 4:** Proactive communication forced by merge blocks (not reactive discovery).
