# Progress: What Works, What's Left

**Update this file when:** A feature reaches "done", a blocker is resolved, or status changes materially.

El historial detallado por fecha vive en [`CHANGELOG.md`](../../CHANGELOG.md) y `git log`.
Este archivo solo lista capacidades de alto nivel y el backlog. El trabajo en vuelo está
en [`04-active-context.md`](04-active-context.md).

---

## Capacidades (qué funciona)

- **Core**: `Actor`, `CurlInterceptor` (con redacción de headers), `Fixture<T>`, `TestStep`,
  `TestFlowLasting`, `TestFlowTransient` (marker), `TesteadorOptions`, `Testeador`.
- **Modos de ejecución**: `registerWithDartTest()` (package:test) y `run(args)` (binario CLI
  con filtros por tags/nombres, fail-fast, exit codes, show-curls, compilación AOT).
- **Aserciones dual-mode (v0.3.0)**: `package:testeador/expect.dart` zone-independent; arregla
  `OutsideTestException` en modo CLI. Tags forwardeados a `group(tags:)`.
- **Ejemplos**: REST (`pokebattle_rest`, dos actores, APIs reales) y Serverpod streaming
  (`pokebattle_serverpod`, server+client+flutter, fan-out `playerAdded`/`battleAdded`/`battleUpdates`).
- **Multidev** (`lib/src/multidev/`): `TargetDevice` (`AndroidEmulator`/`IosSimulator`/`WebDevice`),
  `patrolCommandFor`, `DeviceFleet`, `FlutterActor`, `PatrolRunner`, `ScreenshotComposer` (composite),
  CLI `snapshot_fleet`. WebDevice es target Patrol-web manejado (ver `04`).
- **MCP server** (`testeador mcp`): introspección (`list_suites`/`inspect_suite`/`list_tags`/`dry_run_suite`),
  ejecución (`run_suite_cli`/`run_suite_dart_test`/`compile_suite_exe`), scaffolding, multidev
  (gated), `discover_tests`; resources y prompts. `.mcp.json` wired.
- **Codegen `TestInjector`** (`lib/src/codegen/`): captura `test()` de package:test vía
  build_runner y los inyecta como `TestStep`s. Pipeline 8/8; E2E en `inject_demo` 9/9 y en
  `pokebattle_serverpod_server`.
- **Discover-and-pick**: `dart run testeador discover` (lista/filtra/scaffold de tests
  capturados) más el MCP `discover_tests`. 16/16 tests.
- **Publicación (v0.3.0)**: `CHANGELOG.md`, metadata en pubspec, `.pubignore`; `pub publish --dry-run`
  limpio. Aún `publish_to: none`.

## Backlog / TODO

(Los pains de producto están en [`roadmap.md`](../../roadmap.md); esto es el backlog técnico del paquete.)

- **Alta** (candidato v1.0): rollback real de `TestFlowTransient`; publicación a pub.dev;
  mejores mensajes de error.
- **Media**: múltiples fixtures por flow; error handlers custom; assertions de performance
  (latencia); generación de docs OpenAPI/GraphQL; replay de fixtures.
- **Codegen pendiente**: inyección cross-package real (capturar en un paquete, inyectar desde otro);
  workaround para correr build_runner en los ejemplos Flutter (conflicto `meta`, ver `03`).
- **Baja / fuera de alcance**: visual regression, profiling, tracing distribuido, load testing.

## Issues conocidos

- **TestFlowTransient sin rollback**: read-only flows usan Lasting; los side effects persisten.
- **Dependencia de APIs externas**: los tests fallan si PokéAPI/restful-api.dev caen; usar
  staging/sandbox propios en CI de producción.
- **Complejidad de closure capture**: flows con muchos pasos capturan mucho estado; mantener
  flows enfocados (un escenario por flow).
