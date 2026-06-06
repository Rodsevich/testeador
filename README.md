# testeador

Sequential integration test orchestrator for Dart — runs frontend contract tests inside the backend CI pipeline.

![pub.dev](https://img.shields.io/badge/pub.dev-unpublished-grey)
![Dart SDK](https://img.shields.io/badge/dart-%5E3.11.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

Frontend teams write integration tests that pin down a backend's contract (field names, response shapes, endpoints). Those tests normally run only in the frontend pipeline, so a backend change can silently break them until production. `testeador` runs the *same* frontend tests inside the backend CI, catching contract regressions before they merge. Full rationale: [docs/PROBLEM.md](docs/PROBLEM.md).

## How It Works

Group `TestStep`s into `TestFlow`s and hand them to `Testeador`. Each `Actor` gets a `Dio` instance with a `CurlInterceptor` that records every HTTP call as a cURL command. Flows run sequentially; on failure, `testeador` prints the full cURL log per actor so backend devs reproduce the exact request sequence. Run via `dart test` or compile to a standalone binary with `dart compile exe` — no Dart SDK needed in CI.

> **No mocks.** All HTTP calls must go to real APIs (staging, sandbox, public). In-memory fakes defeat contract testing.

## Concepts

Class signatures and design rationale live in [docs/architecture.md](docs/architecture.md). This section shows how you use each piece.

### Actor

A user persona. Subclass it with a pre-configured `Dio` (base URL, auth headers). `Testeador` injects the `CurlInterceptor` into `actor.dio`, so any call made through that `Dio` is recorded and printed on failure.

```dart
import 'package:testeador/testeador.dart';

class AliceActor extends Actor {
  AliceActor() : super(
    name: 'Alice',
    dio: Dio(BaseOptions(baseUrl: 'https://api.example.com')),
    redactHeaders: {'authorization', 'cookie', 'x-api-key'}, // optional override
  );
}
```

Pass `actor.dio` to any repository or HTTP client so its calls appear in the log.

### Fixture\<T\>

Pre-loads resources before a flow's steps run. Implement `load()` to return a typed context `T`; optionally override `dispose(T)` for cleanup (called even on failure, default no-op).

```dart
class PokemonFixture extends Fixture<PokemonContext> {
  @override
  Future<PokemonContext> load() async {
    final client = PokeApiClient(Dio());
    final fire = await client.fetchPokemon('charizard');
    return PokemonContext(firePokemon: [fire]);
  }
}
```

### TestStep

A single named action. Its `action` is a zero-argument async callback; actors, repositories, and shared state are captured via closure.

```dart
TestStep(
  name: 'Alice creates a resource',
  action: () async {
    final result = await repo.create(name: 'test');
    createdId = result.id; // shared state captured by closure
    expect(result.name, equals('test'));
  },
)
```

### TestFlow

A named, ordered sequence of `TestStep`s with an optional `Fixture` and tags for filtering.

- **`TestFlowLasting`** — side effects intentionally persist (seeding, write-path tests).
- **`TestFlowTransient`** — ⚠️ **TODO**: marker type only, no rollback implemented; behaves like `TestFlowLasting` at runtime.

### Testeador

The orchestrator. Construct it with your flows and actors, then pick a mode:

- **`registerWithDartTest([TesteadorOptions])`** — registers flows as `group()`/`test()` blocks with `package:test`. Run with `dart test`.
- **`run(List<String> args)`** — parses CLI flags, executes sequentially, calls `exit()`. For standalone binaries.

#### CLI flags

| Flag | Default | Description |
| --- | --- | --- |
| `--include-tags` / `--exclude-tags` | — | Comma-separated tags; filter which flows run |
| `--include-flows` / `--exclude-flows` | — | Comma-separated flow names; filter which flows run |
| `--[no-]fail-fast` | `true` | Stop after the first flow failure |
| `--[no-]verbose` / `-v` | `false` | Print step names and fixture events |
| `--[no-]exit-on-failure` | `true` | Exit with code 1 when any flow fails |
| `--[no-]show-curls` | `true` | Print the cURL log on failure |
| `--[no-]show-stack-traces` | `false` | Print Dart stack traces on failure |
| `--help` / `-h` | — | Show usage |

## Quick Start

**1. Add the dependency** (`pubspec.yaml`):

```yaml
dependencies:
  testeador:
    git: https://github.com/your-org/testeador.git
  dio: ^5.0.0
```

**2. Define an actor and a flow** (`test/my_flow.dart`):

```dart
import 'package:testeador/testeador.dart';

class AliceActor extends Actor {
  AliceActor() : super(name: 'Alice', dio: Dio(BaseOptions(baseUrl: 'https://api.example.com')));
}

TestFlowLasting buildMyFlow() {
  final actor = AliceActor();
  final repo = MyRepository(actor.dio);
  String? createdId;

  return TestFlowLasting(
    name: 'Alice — create and retrieve resource',
    tags: {'smoke'},
    steps: [
      TestStep(name: 'Alice creates a resource', action: () async {
        final result = await repo.create(name: 'test');
        createdId = result.id;
        expect(result.name, equals('test'));
      }),
      TestStep(name: 'Alice retrieves the resource', action: () async {
        final result = await repo.getById(createdId!);
        expect(result, isNotNull);
      }),
    ],
  );
}
```

**3. Wire the entry point** (`bin/run_tests.dart`):

```dart
Future<void> main(List<String> args) async {
  await Testeador(flows: [buildMyFlow()], actors: [AliceActor()]).run(args);
}
```

**4. Run:**

```bash
dart run bin/run_tests.dart                                    # all flows
dart run bin/run_tests.dart --include-tags smoke --verbose     # filter by tag
dart run bin/run_tests.dart --include-flows "Alice — create and retrieve resource"
dart compile exe bin/run_tests.dart -o bin/test_runner         # standalone binary (no SDK in CI)
./bin/test_runner --include-tags smoke
```

## CLI

testeador ships a single executable, `testeador`, with subcommands (declared in [`pubspec.yaml`](pubspec.yaml); entrypoint [`bin/testeador.dart`](bin/testeador.dart)).

```bash
dart run testeador --help            # list subcommands
dart run testeador mcp --version     # MCP server smoke check
dart run testeador discover          # list captured tests (codegen)
```

## MCP Server (`testeador mcp`)

`testeador mcp` is a Model Context Protocol server exposing every package feature to any MCP client (Claude Code, Cursor, etc.). Implementation under [`lib/src/mcp/`](lib/src/mcp/).

It operates on the project named by `TESTEADOR_PROJECT_ROOT` (falling back to the nearest ancestor of CWD whose `pubspec.yaml` is or depends on testeador), so consumers add it to their own `.mcp.json`:

```jsonc
{
  "mcpServers": {
    "testeador": {
      "command": "dart",
      "args": ["run", "--no-serve-devtools", "testeador:testeador", "mcp"],
      "cwd": "${workspaceFolder}",
      "env": {
        "TESTEADOR_PROJECT_ROOT": "${workspaceFolder}",
        "TESTEADOR_MCP_ENABLE_MULTIDEV": "1"
      }
    }
  }
}
```

Tool groups:

- **Introspection** — `list_suites`, `inspect_suite`, `list_tags`, `dry_run_suite` (parse suites via the Dart analyzer; never spawn).
- **Execution** — `run_suite_cli`, `run_suite_dart_test`, `compile_suite_exe` (each accepts `execute: false` for command-only; cURL logs and pass/fail counts are parsed out).
- **Scaffolding** — `scaffold_actor`, `scaffold_fixture`, `scaffold_flow`, `scaffold_suite_runner`, `scaffold_dart_test_main` (each accepts `dry_run: true`).
- **Multidev** — `list_devices`, `boot_fleet`, `shutdown_fleet`, `snapshot_fleet`, `run_patrol_fleet` (gated behind `TESTEADOR_MCP_ENABLE_MULTIDEV=1`; require `adb`/`xcrun` for mobile). A **web** device drives a Flutter web app in real Chrome via Patrol 4.0+ (Playwright) and doubles as a headless-Chrome evidence surface for `snapshot_fleet`. Web e2e needs Node + `patrol_cli` 4.x (`dart pub global activate patrol_cli`); first run auto-installs Playwright.
- **Capture** — `start_recording`, `stop_and_generate` (gated behind `TESTEADOR_MCP_ENABLE_CAPTURE=1`). See [Discover contract tests from a running app](#discover-contract-tests-from-a-running-app-record).

It also serves scaffolding templates and project docs as MCP **resources** (`testeador://templates/*`, `testeador://docs/*`) and two **prompts** (`scaffold_suite`, `diagnose_failure`).

## Discover contract tests from a running app (`record`)

`testeador record` (CLI) and the `start_recording`/`stop_and_generate` MCP tools find **which backend contract tests are missing** by passively capturing the HTTP traffic a real app generates while you exercise it — a human tapping, or an AI driving via [`marionette_flutter`](https://pub.dev/packages/marionette_flutter). The UI is the *means*; the deliverable is pure-HTTP contract tests that run in CI with no capture dependency.

Two backends behind one passive capture: **web** via the Chrome DevTools Protocol Network domain, **native** via the Dart VM-service HTTP profiler (Dio/`package:http` over `dart:io`; apps using a native adapter like `cronet_http` bypass it and are reported as zero-capture). Exercised endpoints are templated (`/users/123` → `/users/{id}`), diffed against coverage, and the gaps become draft `TestStep` builders — **secrets redacted** (auth/cookie/api-key headers and `*token*`/`*password*`/`*secret*` body fields never reach the generated source).

```bash
# Web: attach to a Chrome started with --remote-debugging-port=9222
testeador record --backend web --debug-port 9222 --out test/contract_drafts
# Native: attach to a `flutter run` VM-service URI
testeador record --backend native --vm-uri ws://127.0.0.1:8181/ws --duration 30
```

Drafts are written without overwriting; refine them and wire each to the actor whose `Dio` targets that service, then pull them into a flow with `testeador discover --pick`.

## Example

[`example/pokebattle_rest/`](example/pokebattle_rest/) is the REST-backed PokéBattle scenario: two actors (Firesh, Watersh), `TestFlowLasting` flows against real backends — **PokéAPI** for Pokémon data and **restful-api.dev** for players and battles. [`example/pokebattle_serverpod/`](example/pokebattle_serverpod/) is the streaming variant on Serverpod (push auto-updates, multi-device E2E) and ships a **web admin panel** driven end-to-end in real Chrome by Patrol-web. See [`example/pokebattle_rest/README.md`](example/pokebattle_rest/README.md) for details.

```bash
dart run example/pokebattle_rest/bin/run_tests.dart --include-tags smoke --verbose
```

## License

MIT — see [LICENSE](LICENSE).
