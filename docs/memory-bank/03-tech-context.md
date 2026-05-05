# Tech Context: Stack & Constraints

**Update this file when:** Dependencies, SDK version, build tools, or environment constraints change.

---

## Tech Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Dart SDK | ^3.11.0 | Language and runtime |
| dio | ^5.0.0 | HTTP client; enables CurlInterceptor |
| args | ^2.4.0 | CLI argument parsing |
| test | ^1.31.0 | Test framework (for registerWithDartTest mode) |
| mocktail | ^1.0.5 | **Dev only.** Mock framework (for testeador's own tests; not for user flows) |
| very_good_analysis | ^10.2.0 | **Dev only.** Linting and code quality |

## Build & Compilation

### Local Development
```bash
dart pub get
dart test lib/src/ # run testeador's own tests
dart run example/bin/run_tests.dart # run the Pokémon example
```

### Standalone Binary
```bash
dart compile exe bin/run_tests.dart -o bin/test_runner
./bin/test_runner --help
```

Produces a single executable; no Dart SDK needed in CI.

## Execution Modes

### Mode 1: Dart Test (Local Development)
```dart
void main() {
  Testeador(flows: [...], actors: [...]).registerWithDartTest();
}
```

Run with: `dart test test/my_test.dart`

Flows become `group()`/`test()` blocks in the `package:test` framework.

### Mode 2: CLI Binary (CI/Production)
```dart
Future<void> main(List<String> args) async {
  await Testeador(flows: [...], actors: [...]).run(args);
}
```

Compile: `dart compile exe bin/run_tests.dart -o bin/test_runner`  
Run: `./bin/test_runner --include-tags smoke --verbose`

Parses CLI flags, executes flows sequentially, exits with code 0 (pass) or 1 (fail).

## CLI Flags (Mode 2 Only)

| Flag | Type | Default | Example |
|------|------|---------|---------|
| `--include-tags` | CSV | — | `--include-tags smoke,critical` |
| `--exclude-tags` | CSV | — | `--exclude-tags slow` |
| `--include-flows` | CSV | — | `--include-flows "Alice creates"` |
| `--exclude-flows` | CSV | — | `--exclude-flows "Cleanup flow"` |
| `--[no-]fail-fast` | flag | `true` | `--no-fail-fast` to continue after first failure |
| `--[no-]verbose` / `-v` | flag | `false` | `--verbose` to print step names and fixture events |
| `--[no-]exit-on-failure` | flag | `true` | `--no-exit-on-failure` for local testing (always exit 0) |
| `--[no-]show-curls` | flag | `true` | `--no-show-curls` to hide HTTP logs |
| `--[no-]show-stack-traces` | flag | `false` | `--show-stack-traces` to print Dart stack traces |
| `--help` / `-h` | flag | — | Display usage |

## Directory Structure

```
testeador/
├── lib/                              # Public package
│   ├── testeador.dart                # Public exports (barrel file)
│   └── src/
│       ├── actor.dart
│       ├── curl_interceptor.dart
│       ├── fixture.dart
│       ├── test_flow.dart
│       ├── test_step.dart
│       ├── testeador.dart            # Orchestrator (CLI + registerWithDartTest)
│       ├── testeador_options.dart
│       └── [other implementations]
├── example/                          # Pokémon battle example
│   ├── bin/
│   │   └── run_tests.dart            # CLI entry point
│   ├── lib/
│   │   ├── data/                     # HTTP clients
│   │   │   └── api_client.dart
│   │   └── domain/                   # Models and repositories
│   │       ├── models.dart
│   │       └── repositories.dart
│   ├── test/
│   │   ├── actors.dart               # FireshActor, WatershActor
│   │   ├── fixtures/
│   │   │   └── session_fixture.dart  # Auth setup
│   │   └── flows/
│   │       ├── fire_team_flow.dart
│   │       ├── water_team_flow.dart
│   │       └── battle_flow.dart
│   └── pubspec.yaml
├── docs/
│   ├── PRD.md                        # Product Requirements Document
│   ├── PROBLEM.md                    # Problem narrative (Spanish)
│   ├── architecture.md               # Full technical spec
│   ├── memory-bank/                  # This directory
│   │   ├── 00-projectbrief.md
│   │   ├── 01-product-context.md
│   │   ├── 02-system-patterns.md
│   │   ├── 03-tech-context.md        # This file
│   │   ├── 04-active-context.md
│   │   └── 05-progress.md
│   └── [other docs]
├── pubspec.yaml
└── README.md                         # Usage guide
```

## Dart-Specific Patterns

### Language Features in Use
- **Generics:** `Fixture<T>` is a generic class parameterized by context type.
- **Abstract classes:** `Actor`, `Fixture<T>`, `TestFlow` are abstract; subclassed by users.
- **Sealed classes:** `TestFlow` is sealed (TODO: verify in code); `TestFlowLasting` and `TestFlowTransient` are the only subclasses.
- **Extensions/Interceptors:** `CurlInterceptor` extends `Dio.Interceptor`; `dio` package provides the base.
- **Async/await:** All lifecycle methods and actions are async; `Future<T>`, `FutureOr<void>`.
- **Closures:** Heavy use for context capture in `TestStep.action`.

### Testing Testeador Itself
Testeador's own tests use `package:test` and `mocktail` (for mocking `Dio` in unit tests). **Important:** User flows should never use mocks; this is only for testeador's own internal testing.

## CI Integration Examples

### GitHub Actions
```yaml
- name: Run contract tests
  run: |
    dart compile exe bin/run_tests.dart -o test_runner
    ./test_runner --verbose --fail-fast
```

### GitLab CI
```yaml
contract_tests:
  script:
    - dart compile exe bin/run_tests.dart -o test_runner
    - ./test_runner --include-tags smoke
```

### Generic CI (Bash)
```bash
dart compile exe bin/run_tests.dart -o test_runner
./test_runner --exit-on-failure
echo "Exit code: $?"
```

## Environment Constraints

- **Network access:** Tests must reach real APIs (staging, sandbox, or public). Firewall rules must allow outbound HTTP/HTTPS.
- **API availability:** If an external API (e.g., PokéAPI) is down, tests will fail. Use staging/sandbox APIs under your control in production CI.
- **Dart SDK:** ^3.11.0 or later. Compiled binary has no SDK dependency.
- **OS:** Works on Linux, macOS, Windows (tested on macOS; compatibility with others assumed).

## Dependency Rationale

| Dependency | Why | Could it be removed? |
|-----------|-----|----------------------|
| `dio` | HTTP client with interceptor API (enables `CurlInterceptor`) | No; core to the design |
| `args` | CLI argument parsing | Possible, but reinventing the wheel; good library |
| `test` | Framework for `registerWithDartTest()` integration | No; hard dependency for this mode |
| `mocktail` (dev) | Mock framework for testeador's own unit tests | Yes, but mocking is useful internally; kept for dev convenience |
| `very_good_analysis` (dev) | Linting; ensures code quality | No; dev-only; improves maintainability |

## Version Management

- **Testeador:** Currently 0.2.0 (pre-release). Roadmap: v1.0 for pub.dev publication with stable API.
- **Dependencies:** Pinned to ranges (`^X.Y.Z`). Allows bug fixes and minor versions; prevents breaking changes.
- **Dart SDK:** `^3.11.0` ensures access to modern language features (e.g., sealed classes if used).

## Known Build/Runtime Issues

1. **`dart compile exe` binary size:** On macOS, binaries can be 100+ MB. This is normal for Dart AOT compilation. Consider stripping: `strip bin/test_runner`.

2. **Cross-platform compilation:** `dart compile exe` produces a binary for the host platform. To target a different OS, compile on that OS or use cross-compilation tools.

3. **TLS/SSL certificates:** On some CI systems, TLS verification may fail for self-signed certs. Document how to disable (`Dio` has `httpClientAdapter` configuration).
