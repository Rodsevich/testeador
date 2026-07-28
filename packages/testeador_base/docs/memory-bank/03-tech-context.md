# Tech Context

*Update when: dependencies, SDK version, build tools, or environment constraints change.*

Stack (authoritative versions in [pubspec.yaml](../../pubspec.yaml)): Dart SDK `^3.11.0`; `dio` (HTTP + interceptor), `args` (CLI parsing), `test` (for `registerWithDartTest`); dev-only `mocktail` (testeador's own tests — never user flows) and `very_good_analysis` (lint). MCP/codegen add `mcp_dart`, `analyzer`, `source_gen`, `build`, `glob`.

Common commands:

```bash
dart pub get
dart test                                            # testeador's own tests
dart run example/pokebattle_rest/bin/run_tests.dart  # run the example
dart compile exe bin/run_tests.dart -o bin/test_runner   # standalone binary (no SDK in CI)
```

Environment constraints:

- **Network:** tests reach real APIs (staging/sandbox/public); outbound HTTP/HTTPS must be allowed.
- **API availability:** if an external API is down, tests fail — use staging APIs under your control in CI.
- **Multidev (optional):** `adb`/`xcrun` on PATH for mobile; Node + `patrol_cli` 4.x for web e2e.
- **Binary:** `dart compile exe` is host-platform; AOT binaries can be 100+ MB (`strip` to shrink).

CLI flags → [README.md](../../README.md#cli-flags) · directory structure, interfaces, design → [architecture.md](../architecture.md) · current build state → [04-active-context.md](04-active-context.md).
