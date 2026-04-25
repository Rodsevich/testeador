# testeador

Sequential integration test orchestrator for Dart — runs frontend contract tests inside the backend CI pipeline.

![pub.dev](https://img.shields.io/badge/pub.dev-unpublished-grey)
![Dart SDK](https://img.shields.io/badge/dart-%5E3.11.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## The Problem

Frontend teams write integration tests that validate the contracts a backend exposes: API shapes, field names, response structures. Those tests only run in the frontend pipeline, so a backend developer can rename a field or remove an endpoint and nobody notices until the frontend breaks in production. `testeador` lets you run those same frontend tests inside the backend CI pipeline — catching contract regressions before they merge.

## How It Works

You group `TestStep`s into `TestFlow`s and hand them to `Testeador`. Each `Actor` gets its own `Dio` instance with a `CurlInterceptor` that records every outgoing HTTP call as a cURL command. Flows execute sequentially; if a step fails, `testeador` prints the full cURL log for every actor so backend developers can reproduce the exact request sequence. Run via `dart test` or compile to a standalone binary with `dart compile exe` — no Dart SDK required in CI.

> **No mocks.** `testeador` is for integration tests. All HTTP calls must go to real APIs.
> In-memory stores and local fakes defeat the purpose of contract testing.

## Concepts

### Actor

An `Actor` represents a user persona in a test flow. Subclass it to provide a pre-configured `Dio` instance (base URL, auth headers, etc.). `Testeador` injects the `CurlInterceptor` into `actor.dio` before running, so all HTTP calls made through that `Dio` are recorded and printed on failure.

```dart
import 'package:testeador/testeador.dart';

class MyActor extends Actor {
  MyActor() : super(
    name: 'MyActor',
    dio: Dio(BaseOptions(baseUrl: 'https://api.example.com')),
  );
}

// Actor with custom header redaction
class AdminActor extends Actor {
  AdminActor() : super(
    name: 'Admin',
    dio: Dio(BaseOptions(baseUrl: 'https://api.example.com')),
    redactHeaders: {'authorization', 'cookie', 'x-api-key'},
  );
}
```

Pass `actor.dio` to any repository or HTTP client so its calls appear in the cURL log.

### Fixture\<T\>

A `Fixture<T>` pre-loads resources before a flow's steps run. Subclass it, implement `load()` to return a typed context object `T`, and optionally override `dispose(T)` for cleanup (called even on failure).

```dart
class PokemonContext {
  const PokemonContext({required this.firePokemon, required this.waterPokemon});
  final List<Pokemon> firePokemon;
  final List<Pokemon> waterPokemon;
}

class PokemonFixture extends Fixture<PokemonContext> {
  @override
  Future<PokemonContext> load() async {
    final dio = Dio();
    final client = PokeApiClient(dio);
    final fire = await Future.wait([
      client.fetchPokemon('charizard'),
      client.fetchPokemon('arcanine'),
    ]);
    final water = await Future.wait([
      client.fetchPokemon('blastoise'),
      client.fetchPokemon('vaporeon'),
    ]);
    return PokemonContext(firePokemon: fire, waterPokemon: water);
  }
  // dispose() is a no-op by default — override if you need cleanup
}
```

### TestStep

A `TestStep` is a single named action. Its `action` is a zero-argument async callback; actors, repositories, and shared state are captured via closure.

```dart
String? createdId; // shared mutable state across steps

TestStep(
  name: 'Alice creates a resource',
  action: () async {
    final result = await repo.create(name: 'test');
    createdId = result.id;
    expect(result.name, equals('test'));
  },
),
```

### TestFlow

A `TestFlow` is a named, ordered sequence of `TestStep`s with an optional `Fixture` and a set of tags for filtering.

- **`TestFlowLasting`** — side effects intentionally persist after execution (seeding data, write-path tests).
- **`TestFlowTransient`** — ⚠️ **TODO**: marker type only. No rollback is implemented. Behaves identically to `TestFlowLasting` at runtime.

```dart
TestFlowLasting buildMyFlow() {
  final actor = MyActor();
  final repo = MyRepository(actor.dio);
  String? createdId;

  return TestFlowLasting(
    name: 'Alice — create and retrieve resource',
    tags: {'smoke'},
    steps: [
      TestStep(
        name: 'Alice creates a resource',
        action: () async {
          final result = await repo.create(name: 'test');
          createdId = result.id;
          expect(result.name, equals('test'));
        },
      ),
      TestStep(
        name: 'Alice retrieves the resource',
        action: () async {
          final result = await repo.getById(createdId!);
          expect(result, isNotNull);
        },
      ),
    ],
  );
}
```

### Testeador

`Testeador` is the top-level orchestrator. Construct it with your flows and actors, then choose an execution mode:

**`registerWithDartTest([TesteadorOptions])`** — registers flows as `group()`/`test()` blocks with `package:test`. Call from `main()` in a `*_test.dart` file.

```dart
// test/pokemon_suite_test.dart
void main() {
  final actor = MyActor();
  Testeador(
    flows: [buildMyFlow()],
    actors: [actor],
  ).registerWithDartTest(
    const TesteadorOptions(verbose: true),
  );
}
```

Run with: `dart test test/pokemon_suite_test.dart`

**`run(List<String> args)`** — parses CLI flags, executes flows sequentially, prints results, and calls `exit()`. Use for standalone binaries.

```dart
// bin/run_tests.dart
Future<void> main(List<String> args) async {
  final actor = MyActor();
  await Testeador(
    flows: [buildMyFlow()],
    actors: [actor],
  ).run(args);
}
```

#### CLI flags

| Flag | Default | Description |
|---|---|---|
| `--include-tags` | — | Comma-separated tags; only matching flows run |
| `--exclude-tags` | — | Comma-separated tags; matching flows are skipped |
| `--include-flows` | — | Comma-separated flow names; only matching flows run |
| `--exclude-flows` | — | Comma-separated flow names; matching flows are skipped |
| `--[no-]fail-fast` | `true` | Stop after the first flow failure |
| `--[no-]verbose` / `-v` | `false` | Print step names and fixture events as they run |
| `--[no-]exit-on-failure` | `true` | Exit with code 1 when any flow fails |
| `--[no-]show-curls` | `true` | Print the cURL log for actors on failure |
| `--[no-]show-stack-traces` | `false` | Print Dart stack traces on failure |
| `--help` / `-h` | — | Show usage |

## Quick Start

**1. Add the dependency:**

```yaml
# pubspec.yaml
dependencies:
  testeador:
    git: https://github.com/your-org/testeador.git
  dio: ^5.0.0
```

**2. Create an actor and a flow:**

```dart
// test/my_flow.dart
import 'package:testeador/testeador.dart';
import 'package:test/test.dart';

class AliceActor extends Actor {
  AliceActor() : super(
    name: 'Alice',
    dio: Dio(BaseOptions(baseUrl: 'https://api.example.com')),
  );
}

TestFlowLasting buildMyFlow() {
  final actor = AliceActor();
  final repo = MyRepository(actor.dio);
  String? createdId;

  return TestFlowLasting(
    name: 'Alice — create and retrieve resource',
    tags: {'smoke'},
    steps: [
      TestStep(
        name: 'Alice creates a resource',
        action: () async {
          final result = await repo.create(name: 'test');
          createdId = result.id;
          expect(result.name, equals('test'));
        },
      ),
      TestStep(
        name: 'Alice retrieves the resource',
        action: () async {
          final result = await repo.getById(createdId!);
          expect(result, isNotNull);
        },
      ),
    ],
  );
}
```

**3. Wire up the entry point:**

```dart
// bin/run_tests.dart
import 'package:testeador/testeador.dart';
import '../test/my_flow.dart';

Future<void> main(List<String> args) async {
  final actor = AliceActor();
  await Testeador(
    flows: [buildMyFlow()],
    actors: [actor],
  ).run(args);
}
```

**4. Run:**

```bash
dart run bin/run_tests.dart
dart run bin/run_tests.dart --include-tags smoke --verbose
```

## CLI Usage

```bash
# Run all flows
dart run bin/run_tests.dart

# Run only flows tagged 'smoke'
dart run bin/run_tests.dart --include-tags smoke

# Run a specific flow by name
dart run bin/run_tests.dart --include-flows "Alice — create and retrieve resource"

# Verbose output, don't stop on first failure
dart run bin/run_tests.dart --verbose --no-fail-fast

# Compile to a standalone binary (no Dart SDK needed in CI)
dart compile exe bin/run_tests.dart -o bin/test_runner
./bin/test_runner --include-tags smoke --verbose
```

## Example

The [`example/`](example/) directory contains a complete Pokémon battle scenario with two actors (Firesh and Watersh) and three `TestFlowLasting` flows running against two real HTTP backends: **PokéAPI** (`https://pokeapi.co/api/v2`) for Pokémon data and **restful-api.dev** (`https://api.restful-api.dev`) for player registration and battles. See [`example/README.md`](example/README.md) for details.

```bash
dart run example/bin/run_tests.dart
dart run example/bin/run_tests.dart --include-tags smoke --verbose
```

## License

MIT — see [LICENSE](LICENSE).
