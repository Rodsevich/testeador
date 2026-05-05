# System Patterns & Architecture Summary

**Update this file when:** Major design decisions change, or new architectural patterns emerge.

---

## Core Abstraction Stack

```
Testeador (orchestrator)
  ├─ TestFlow (sequential steps)
  │   ├─ TestStep (named actions)
  │   └─ Fixture<T> (setup/teardown)
  └─ Actor (user persona)
      └─ CurlInterceptor (HTTP observability)
```

## Key Design Principles

### 1. Sequential Execution Only
Steps within a flow run in declaration order. No concurrency. Eliminates race conditions and non-determinism.

### 2. No Mocks; Real APIs Required
All HTTP calls go to real APIs (staging, sandbox, public). In-memory fakes defeat the purpose of contract testing. This is non-negotiable.

### 3. Closure Capture for Context
`TestStep.action` is a zero-argument function. Actors, repos, and shared state are captured from the enclosing scope via closure.

```dart
String? createdId; // shared mutable state
TestStep(
  name: 'Create resource',
  action: () async {
    final result = await repo.create(name: 'test');
    createdId = result.id; // captured by closure
    expect(result.name, equals('test'));
  },
)
```

**Rationale:** Simple API (no generic type parameters on TestStep); natural Dart idiom; easy to read flows.

### 4. Actor Model: Independent HTTP Logs
Each `Actor` has its own `CurlInterceptor`. When a flow runs with multiple actors, each actor's HTTP log is independent and printed separately on failure. This makes multi-user scenarios (e.g., Alice acts, Bob acts, then Alice acts again) transparent and reproducible.

### 5. Fixture Lifecycle: Declarative Setup/Teardown
Each `TestFlow` holds one optional `Fixture<T>`. The fixture is responsible for:
- **`load()`** — called once before steps run; returns typed context `T`.
- **`dispose(T)`** — called once after all steps, even on failure (finally block); default is no-op.

This keeps flows self-contained and independently runnable.

### 6. TestFlowLasting vs. TestFlowTransient
- **`TestFlowLasting`** — side effects intentionally persist (seeding data, write-path tests). Implemented and working.
- **`TestFlowTransient`** — marker type for read-only flows (rollback not yet implemented; behaves as Lasting). **TODO:** implement rollback strategy (transaction scope callback or RollbackStrategy interface).

### 7. Dual Execution Modes
- **`registerWithDartTest()`** — integrates with `package:test`; flows become `group()/test()` blocks. For local development via `dart test`.
- **`run(args)`** — CLI mode; parses args, executes sequentially, prints results, calls `exit()`. For standalone binary (compiled with `dart compile exe`).

Both modes inject `CurlInterceptor` into actors before running.

### 8. HTTP Interception via Dio
`CurlInterceptor` is a `Dio` interceptor subclass. It overrides `onRequest()` to record each request as a cURL command before passing to the next interceptor.

**cURL format:**
```
curl -X GET -H 'Content-Type: application/json' -H 'Authorization: [REDACTED]' 'https://api.example.com/users?id=123'
```

Header redaction is enabled by default (`authorization`, `cookie`); customizable per actor.

### 9. Filtering: Tags and Flow Names
Testeador supports filtering via CLI flags:
- `--include-tags` / `--exclude-tags` — comma-separated set intersection.
- `--include-flows` / `--exclude-flows` — exact name match.

Example: `--include-tags smoke,critical` runs only flows with both or either tag.

## Class Relationships

| Class | Role | Lifetime | Owned By |
|-------|------|----------|----------|
| `Testeador` | Orchestrator | Per-run | Main entry point (bin/run_tests.dart) |
| `TestFlow` | Container for steps + fixture | Per-run | Testeador (flows list) |
| `TestStep` | Named action | Per-execution | TestFlow (steps list) |
| `Fixture<T>` | Setup/teardown | Per-flow | TestFlow (optional fixture) |
| `Actor` | User persona + HTTP log | Shared across flows | Testeador (actors list); created in main |
| `CurlInterceptor` | HTTP observability | Per-actor | Actor (created at Actor construction) |
| `Dio` | HTTP client | Per-actor | Actor (injected at construction) |

## Execution Flow

```
1. main() creates actors and flows.
2. Testeador(...).run(args) or .registerWithDartTest(options).
3. Before first flow: Testeador._injectInterceptors() adds CurlInterceptor to each actor's Dio.
4. For each flow (filtered by tags/names):
   a. Clear cURL logs for all actors.
   b. Call fixture.load() if present → returns context T.
   c. For each step:
      - Call step.action() (captures actors, context, shared state via closure).
      - On error: print failure message + cURL logs (if --show-curls).
      - If failFast, break; else continue.
   d. Call fixture.dispose(T) in finally block.
5. Exit with code 0 (all passed) or 1 (any failed, if --exit-on-failure).
```

## Common Patterns

### Pattern 1: Shared Mutable State Across Steps
```dart
String? createdId;
TestStep(name: 'Create', action: () async {
  final result = await repo.create(...);
  createdId = result.id;
}),
TestStep(name: 'Retrieve', action: () async {
  final result = await repo.getById(createdId!);
  expect(result, isNotNull);
}),
```

### Pattern 2: Fixture-Provided Context
```dart
TestFlowLasting(
  fixture: MyFixture(),
  steps: [
    TestStep(name: 'Use context', action: () async {
      // context is captured from the flow constructor
      expect(context.someValue, equals(expected));
    }),
  ],
)
```

### Pattern 3: Multi-Actor Collaboration
```dart
final alice = AliceActor();
final bob = BobActor();
TestFlowLasting(
  steps: [
    TestStep(name: 'Alice acts', action: () async {
      await aliceRepo.doSomething(alice.dio);
    }),
    TestStep(name: 'Bob reacts', action: () async {
      final result = await bobRepo.getState(bob.dio);
      expect(result, equals(expectedState));
    }),
  ],
),
```

## Known Limitations & TODOs

1. **TestFlowTransient rollback is unimplemented.** Currently, `TestFlowTransient` is a marker type; it behaves identically to `TestFlowLasting`. Decision on rollback strategy deferred pending real-world usage data.

2. **No built-in performance assertions.** Testeador is for correctness, not scale. Latency assertions would require timestamps in cURL; deferred.

3. **No automatic contract documentation.** OpenAPI/GraphQL schema generation from flows would be nice but is out of scope for v0.2.0.

## Related Documentation

- **[docs/architecture.md](../architecture.md)** — Full technical spec with class diagrams and method signatures.
- **[docs/PROBLEM.md](../PROBLEM.md)** — Problem narrative with mermaid diagrams.
- **[README.md](../../README.md)** — Usage guide and quick start.
