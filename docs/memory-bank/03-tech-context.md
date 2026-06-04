# Tech Context: Stack & Constraints

**Update this file when:** Dependencies, SDK version, build tools, or environment constraints change.

---

Dart SDK `^3.11.0`; deps núcleo `dio`, `args`, `test`; dev `mocktail`,
`very_good_analysis` (+ `build`/`source_gen`/`build_runner` para el codegen). Versiones
exactas en [`pubspec.yaml`](../../pubspec.yaml).

Dos modos de ejecución: `dart test` (`registerWithDartTest()`) y binario CLI
(`dart compile exe` + `run(args)`).

Punteros al detalle (todo en [`docs/architecture.md`](../architecture.md)):

- **Estructura de directorios:** §File Structure.
- **Flags de CLI:** §CLI flags (standalone binary mode), también en [`README.md`](../../README.md).
- **Racional de dependencias:** §Dependency Rationale.
- **Restricciones de entorno (red, APIs reales, SDK, OS):** §Environment Constraints.
- **Gotchas de build/runtime (tamaño del binario AOT, cross-compilation, TLS):** §Known Build/Runtime Issues.
- **Conflicto de resolución `meta`/`flutter_test` que afecta a los ejemplos Flutter:** §Dependency Rationale.
