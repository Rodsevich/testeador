# System Patterns & Architecture Summary

**Update this file when:** Major design decisions change, or new architectural patterns emerge.

---

Stack de abstracciones: `Testeador` (orquestador) → `TestFlow` (pasos secuenciales) →
`TestStep` + `Fixture<T>`; `Actor` (persona) → `CurlInterceptor` (observabilidad HTTP).

Invariantes no-negociables (detalle y diagramas en
[`docs/architecture.md`](../architecture.md) §Class Hierarchy / §Execution flow /
§Key Design Decisions):

- **Ejecución secuencial** dentro de un flow, en orden de declaración. Sin concurrencia.
- **Sin mocks**: todo HTTP va a APIs reales (staging/sandbox/públicas).
- **Closure capture**: `TestStep.action` es zero-arg; actores/repos/estado se capturan del scope.
- **Un log HTTP por actor**: cada `Actor` tiene su `CurlInterceptor`, impreso por separado al fallar.
- **Una `Fixture<T>` opcional por flow**: `load()` antes, `dispose()` en `finally`.
- **`TestFlowLasting` vs `TestFlowTransient`**: Transient es marker (rollback TODO; hoy se comporta como Lasting).
- **Doble modo de ejecución**: `registerWithDartTest()` (package:test) y `run(args)` (binario CLI).
