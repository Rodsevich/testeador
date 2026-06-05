# System Patterns

*Update when: major design decisions change or new patterns emerge.*

Abstraction stack: `Testeador` (orchestrator) → `TestFlow` (sequential `TestStep`s + optional `Fixture<T>`) → `Actor` (persona) → `CurlInterceptor` (HTTP observability).

Key principles (rules-at-a-glance — full rationale, interfaces, and diagrams in [architecture.md](../architecture.md)):

- **Sequential execution only** — steps run in declaration order; no concurrency.
- **No mocks** — all HTTP to real APIs; non-negotiable.
- **Closure capture** — `TestStep.action` is zero-argument; context captured from scope.
- **Per-actor cURL logs** — each `Actor` has its own `CurlInterceptor`; logs cleared per flow, printed on failure.
- **Fixture lifecycle** — one optional `Fixture` per flow; `load()` before steps, `dispose()` in `finally`.
- **Lasting vs. Transient** — `TestFlowLasting` persists; `TestFlowTransient` is a marker (rollback TODO).
- **Dual execution** — `registerWithDartTest()` (dart test) and `run(args)` (CLI binary); both inject interceptors first.
- **Filtering** — by tags and flow names via CLI flags / `TesteadorOptions`.

Open TODOs: `TestFlowTransient` rollback (strategy TBD); no built-in latency assertions; no auto contract-doc generation. See [05-progress.md](05-progress.md) for status.
