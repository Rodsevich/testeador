# Agent Memory Bank — Testeador

## Repository Purpose

`testeador` is a Dart package that orchestrates sequential integration test flows for contract testing between frontend and backend teams. It groups `TestStep`s into `TestFlow`s, provides each actor with a `Dio` instance whose `CurlInterceptor` records every HTTP call as a cURL command, and prints those cURLs on failure so backend developers can reproduce the exact request sequence. It runs either via `dart test` or as a compiled standalone binary (no Dart SDK required in CI).

## Critical Rules

- **No mocks.** `testeador` is for integration tests. Never use in-memory stores, local fakes,
  or mock objects for the backend under test. All HTTP calls must go to real APIs (staging,
  sandbox, or public test APIs). Mocks defeat the purpose of contract testing.
- **Sequential only.** Steps within a flow always run in declaration order. Never introduce
  concurrency within a flow.
- **Closure capture for context.** `TestStep.action` is a zero-argument function; actors,
  repos, and shared state are captured from the enclosing scope.
- **`TestFlowTransient` is a TODO marker.** It has no rollback behavior. Do not document or
  use it as if rollback is implemented.
- **Always pass all actors to `Testeador(actors: [...])`.** This ensures their cURL logs are
  cleared before each flow and printed on failure.

## Core Architecture

### Classes (`lib/src/`)

**`Actor`** — Abstract class representing a user persona executing actions in a test flow. Subclasses provide the `Dio` instance (pre-configured with base URL, auth headers, etc.). The `curlInterceptor` field is created at construction time; `Testeador` injects it into `actor.dio` before running via `_injectInterceptors()`. The `curlInterceptor` field exposes `log` (read) and `clear()` (called by `Testeador` before each flow). Accepts a `redactHeaders` set (default: `{'authorization', 'cookie'}`) to mask sensitive header values in the log.

```dart
class FireshActor extends Actor {
  FireshActor() : super(
    name: 'Firesh',
    dio: Dio(BaseOptions(baseUrl: 'https://api.example.com')),
  );
}
```

**`CurlInterceptor`** — A `Dio` `Interceptor` subclass that records every outgoing request as a cURL command string in an internal `_log` list. Exposes `log` (unmodifiable list), `clear()`, and `redactHeaders`. Overrides only `onRequest`; does not override `onError`. Injected into each `Actor`'s `Dio` instance by `Testeador` before each run.

**`Fixture<T>`** — Abstract generic class for managing resources needed before a `TestFlow` runs. Subclasses implement `Future<T> load()` (called once before steps execute; returns a typed context object) and optionally override `Future<void> dispose(T data)` (called after all steps, even on failure; default is a no-op). The context `T` is captured by step closures at flow-construction time.

**`TestStep`** — A single named action within a `TestFlow`. Has a `name` (shown in output), an optional `description`, and an `action` (`FutureOr<void> Function()`) that is a zero-argument async callback. Context (actors, repos, shared state) is captured via closure at the call site. `execute()` simply calls `action()`.

**`TestFlow` / `TestFlowLasting` / `TestFlowTransient`** — `TestFlow` is the sealed base with `name`, `description`, `steps` (list of `TestStep`), `fixture` (optional `Fixture<dynamic>`), and `tags` (set of strings for filtering). `TestFlowLasting` is a concrete subclass for flows whose side effects intentionally persist (seeding data, write-path tests). `TestFlowTransient` is a **marker-only** concrete subclass — no rollback is implemented; it behaves identically to `TestFlowLasting` at runtime. Both pass all constructor parameters to `super`.

**`TesteadorOptions`** — Immutable value class holding run configuration: `includeTags`, `excludeTags`, `includeFlows`, `excludeFlows` (all `Set<String>`), `failFast` (default `true`), `verbose` (default `false`), `exitOnFailure` (default `true`), `showCurls` (default `true`), `showStackTraces` (default `false`). Used by both `registerWithDartTest()` and `run()`.

**`Testeador`** — Top-level orchestrator. Constructed with `flows` (`List<TestFlow>`) and `actors` (`List<Actor>`, default empty). Calls `_injectInterceptors()` at the start of both `registerWithDartTest()` and `run()`, which adds each actor's `curlInterceptor` to their `dio.interceptors` if not already present. Provides two execution modes: `registerWithDartTest([TesteadorOptions])` registers flows as `group()`/`test()` blocks with `package:test` (for `dart test` integration); `run(List<String> args)` parses CLI flags, executes flows sequentially, prints results to stdout/stderr, and calls `exit()`. In both modes, actor cURL logs are cleared before each flow and printed on failure (in `run()` mode only).

### Public API (`lib/testeador.dart`)

Exports: `Actor`, `CurlInterceptor`, `Fixture`, `TestFlow`, `TestFlowLasting`, `TestFlowTransient`, `TestStep`, `Testeador`, `TesteadorOptions`.

## Example (`example/`)

The Pokémon example demonstrates two actors — **Firesh** (fire-type) and **Watersh** (water-type) — running three sequential flows against two real HTTP backends: **PokéAPI** (`https://pokeapi.co/api/v2`) for Pokémon data and **restful-api.dev** (`https://api.restful-api.dev`) for player registration and battles. No mocks are used.

Two concrete actor subclasses exist in `example/test/actors.dart`: `FireshActor` and `WatershActor`, each providing their own `Dio` instance.

The three flows are:
- **`buildFireTeamFlow()`** — Firesh registers with her 6 fire Pokémon and verifies she appears in the player list.
- **`buildWaterTeamFlow()`** — Watersh registers with her 6 water Pokémon, verifies her own listing, and confirms Firesh is visible.
- **`buildBattleFlow()`** — Firesh selects 3 Pokémon and issues a battle challenge; Watersh views it and confirms she sees who she fights and with what.

The entry point is `example/bin/run_tests.dart`, which calls `Testeador(...).run(args)`.

Run with:
```bash
dart run example/bin/run_tests.dart
dart run example/bin/run_tests.dart --include-tags smoke --verbose
```

## Common Tasks

### Creating a new test flow

1. Define a `Fixture<T>` subclass if the flow needs pre-loaded data or resources.
2. Subclass `Actor` to define a concrete actor with its own `Dio` instance (base URL, auth, etc.).
3. Define a list of `TestStep`s; capture actors, repos, and shared mutable state via closure.
4. Return a `TestFlowLasting` (or `TestFlowTransient` as a marker) with `name`, `steps`, `fixture`, and `tags`.
5. Add the flow to the `Testeador` flows list in your entry point.

### Running the example

```bash
# Standalone CLI (from repo root):
dart run example/bin/run_tests.dart

# With filtering:
dart run example/bin/run_tests.dart --include-tags smoke --verbose
dart run example/bin/run_tests.dart --include-flows "Firesh — registers fire team"

# Compile to binary:
dart compile exe example/bin/run_tests.dart -o bin/test_runner
./bin/test_runner --include-tags smoke
```

### Adding a new Actor

```dart
// In your test/actors.dart:
class MyActor extends Actor {
  MyActor() : super(
    name: 'MyActor',
    dio: Dio(BaseOptions(baseUrl: 'https://api.example.com')),
    // Optionally extend the redacted headers set:
    redactHeaders: {'authorization', 'cookie', 'x-api-key'},
  );
}

MyActor myActor() => MyActor();
```

Pass `myActor().dio` to any repository or client that makes HTTP calls. Register the actor in `Testeador(actors: [...])` so its cURL log is cleared and printed automatically.

## Guidelines

- **Do not modify `lib/` or `example/` when writing docs.** Documentation lives in `AGENTS.md`, `README.md`, and `docs/`.
