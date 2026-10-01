# testeador_base — contract test orchestrator for Dart

Pure-Dart integration test runner for backend contract testing. Frontend teams
write flows that pin down a backend's API contract (field names, response
shapes, endpoints). `testeador_base` runs those same tests inside the backend
CI, catching regressions before they merge.

Full rationale: [docs/PROBLEM.md](docs/PROBLEM.md).

> **No mocks.** All HTTP calls must go to real APIs (staging, sandbox, public).
> In-memory fakes defeat contract testing.

## Concepts

Class signatures and design rationale live in [docs/architecture.md](docs/architecture.md).

### Actor

A user persona. Subclass it with a pre-configured `Dio` (base URL, auth headers). `Testeador` injects the `CurlInterceptor` into `actor.dio`, so any call made through that `Dio` is recorded and printed on failure.

```dart
import 'package:testeador_base/testeador_base.dart';

class AliceActor extends Actor {
  AliceActor() : super(
    name: 'Alice',
    dio: Dio(BaseOptions(baseUrl: 'https://api.example.com')),
    redactHeaders: {'authorization', 'cookie', 'x-api-key'},
  );
}
```

### Fixture\<T\>

Pre-loads resources before a flow's steps run. Implement `load()` to return a typed context `T`; optionally override `dispose(T)` for cleanup.

```dart
class MyFixture extends Fixture<MyWorld> {
  @override
  Future<MyWorld> load() async {
    final client = MyApiClient(Dio());
    return MyWorld(client: client);
  }
}
```

### TestStep

A single named action. Actors, repos, and shared state are captured via closure.

```dart
TestStep(
  name: 'Alice creates a resource',
  action: () async {
    final result = await repo.create(name: 'test');
    createdId = result.id;
    expect(result.name, equals('test'));
  },
)
```

### TestFlow

A named, ordered sequence of `TestStep`s with an optional `Fixture` and tags.

- **`TestFlowLasting`** — side effects persist (seeding, write-path tests).
- **`TestFlowTransient`** — marker only; no rollback implemented yet.

### Testeador

The orchestrator. Two modes:

- **`registerWithDartTest([TesteadorOptions])`** — registers as `group()`/`test()` blocks. Run with `dart test`.
- **`run(List<String> args)`** — parses CLI flags, executes sequentially, calls `exit()`. For standalone binaries.

#### CLI flags

| Flag | Default | Description |
| --- | --- | --- |
| `--include-tags` / `--exclude-tags` | — | Filter by tags |
| `--include-flows` / `--exclude-flows` | — | Filter by flow names |
| `--[no-]fail-fast` | `true` | Stop after first failure |
| `--[no-]verbose` / `-v` | `false` | Print step names and fixture events |
| `--[no-]exit-on-failure` | `true` | Exit code 1 on any failure |
| `--[no-]show-curls` | `true` | Print cURL log on failure |
| `--[no-]show-stack-traces` | `false` | Print Dart stack traces on failure |

## Quick start

```yaml
# pubspec.yaml
dev_dependencies:
  testeador_base: ^0.4.0
  dio: ^5.0.0
```

```dart
// test/my_flow_test.dart
import 'package:testeador_base/testeador_base.dart';

void main() async {
  final testeador = Testeador(
    flows: [buildMyFlow()],
    actors: [AliceActor()],
  );
  testeador.registerWithDartTest();
}
```

```bash
dart test
```

## CLI (`dart run testeador_base:testeador`)

```bash
dart run testeador_base:testeador --help          # list subcommands
dart run testeador_base:testeador mcp --version   # MCP server smoke check
dart run testeador_base:testeador discover        # list captured tests
dart run testeador_base:testeador skills install  # install AI skills (Stage 4)
```

## MCP server

`testeador_base:testeador mcp` exposes every package feature to any MCP client. Add it to `.mcp.json`:

```jsonc
{
  "mcpServers": {
    "testeador": {
      "command": "dart",
      "args": ["run", "--no-serve-devtools", "packages/testeador_base/bin/testeador.dart", "mcp"],
      "env": {
        "TESTEADOR_PROJECT_ROOT": "packages/testeador_base",
        "TESTEADOR_MCP_ENABLE_MULTIDEV": "1"
      }
    }
  }
}
```

Tool groups: **Introspection**, **Execution**, **Scaffolding**, **Multidev**, **Capture**, **Live**. Full docs: [docs/architecture.md](docs/architecture.md).

## Mirador

`testeador_base:mirador` is the visual review panel for UI evidence captured by `testeador` (the Flutter package):

```bash
dart run testeador_base:mirador review --port 4799   # open the panel
dart run testeador_base:mirador promote --scenario s --actor a --slugs s1,s2
```

Full reference: [docs/architecture.md — Mirador](docs/architecture.md#mirador).

## Example

[`example/pokebattle_rest/`](example/pokebattle_rest/) — two actors against PokéAPI and restful-api.dev.
[`example/pokebattle_serverpod/`](example/pokebattle_serverpod/) — streaming Serverpod backend + web admin panel.

```bash
dart run example/pokebattle_rest/bin/run_tests.dart --include-tags smoke --verbose
```

## License

MIT — see [LICENSE](../../LICENSE).
