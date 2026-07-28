# Project Brief: Testeador

*Update when: scope, name, or fundamental purpose changes.*

Testeador is a Dart package that orchestrates sequential integration test flows for contract testing. Frontend teams write tests once; they run in both frontend and backend CI, catching API contract breaks before production.

- **In:** frontend test flows (`TestFlowLasting`/`TestFlowTransient`) and actors (personas).
- **Out:** pass/fail; on failure, a cURL log to reproduce the exact request sequence.
- **Key constraint:** no mocks — all HTTP calls hit real APIs.
- **Status:** v0.2.0, public API stable, `publish_to: none` (pub.dev on roadmap). Dart SDK `^3.11.0`.

Why it exists → [PROBLEM.md](../PROBLEM.md) · product detail → [PRD.md](../PRD.md) · usage → [README.md](../../README.md).
