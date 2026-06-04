# docs: comprimir el memory-bank a un mínimo

**Tipo:** refactor (documentación)
**Fecha:** 2026-06-04
**Estado:** plan

---

## Objetivo

Reducir el memory-bank de **814 líneas en 6 archivos** a su mínimo no-redundante
(**objetivo: ~150 líneas, ≈80% menos**), **sin borrar ningún archivo**. Cada uno de
los 6 archivos se conserva pero se comprime: se elimina toda prosa que duplique un
doc canónico y se reemplaza por un puntero de una línea. El contenido único que hoy
vive solo en el memory-bank se **migra primero** a su doc canónico para no perder
información.

Esto alinea el memory-bank con la regla que el propio
[`AGENTS.md`](../../AGENTS.md) §Guidelines ya declara: *"Single source of truth —
do not duplicate prose across README, AGENTS, architecture, PRD, and the memory
bank."* Hoy esa regla está rota.

## Contexto y diagnóstico

Auditoría de solapamiento (origen → fuente canónica que ya lo contiene):

| Archivo | Líneas | Duplica | Contenido único a preservar |
|---|---|---|---|
| [`00-projectbrief.md`](../memory-bank/00-projectbrief.md) | 35 | `PRD.md` §Executive Summary, `README.md` | Nada (todo derivable) |
| [`01-product-context.md`](../memory-bank/01-product-context.md) | 58 | `PRD.md` §Problem/Personas, `PROBLEM.md` | Nada (todo derivable) |
| [`02-system-patterns.md`](../memory-bank/02-system-patterns.md) | 166 | `architecture.md` §Class Hierarchy/§Execution flow/§Key Design Decisions | Nada (verificar 1:1) |
| [`03-tech-context.md`](../memory-bank/03-tech-context.md) | 191 | `pubspec.yaml`, `README.md` (flags), `architecture.md` §File Structure | **Dependency Rationale**, **Known Build/Runtime Issues**, **Environment Constraints** |
| [`04-active-context.md`](../memory-bank/04-active-context.md) | 145 | `git log` / `git diff` (detalle por-archivo) | **Current focus**, **Active Decision Points**, **Known Blockers**, **Next Steps** |
| [`05-progress.md`](../memory-bank/05-progress.md) | 219 | `CHANGELOG.md`, `git log`, `roadmap.md` | Checklist de capacidades de alto nivel (resumible) |

Conclusión: 00/01/02 son 100% derivables → quedan como punteros. 03 tiene 3
fragmentos a migrar. 04/05 son los únicos con valor real pero están inflados con
detalle que pertenece a git/CHANGELOG.

## Estrategia (orden de ejecución)

### Fase 0 — Migrar contenido único a docs canónicos (antes de comprimir nada)

Auditar y mover los fragmentos no-derivables a su hogar canónico. **Solo migrar lo
que NO esté ya presente** en el destino. **Localizar cada fragmento por su título de
sección (no por número de línea — los números derivan rápido) y `grep` el destino
antes de pegar.**

- [ ] **`03` → `architecture.md`**: agregar (confirmado ausentes hoy en
  `architecture.md`) tres subsecciones, copiando desde `03-tech-context.md` por
  título de sección:
  - `### Dependency Rationale` — desde §Dependency Rationale de `03` (por qué
    `dio`/`args`/`test`/`mocktail`/`very_good_analysis` y si son removibles).
  - `### Known Build/Runtime Issues` — desde §Known Build/Runtime Issues de `03`
    (tamaño del binario AOT en macOS / strip, cross-compilation por host, TLS
    self-signed).
  - `### Environment Constraints` — desde §Environment Constraints de `03`
    (network access / API availability / SDK / OS), si no lo cubre `architecture.md`
    §Overview.
- [ ] **`02` → `architecture.md`**: `grep` para confirmar que el contenido de `02`
  ya está en `architecture.md` (`grep -n "Sequential Execution\|Closure Capture\|Dual Execution"`).
  Se espera cobertura total (confirmado en revisión: `02` es espejo 1:1 de
  `architecture.md` §Key Design Decisions / §Execution flow / §Class Hierarchy). Único
  matiz a verificar: la redacción de headers `authorization`/`cookie` *por-actor*
  (§Actor Model en `02`); si falta en `architecture.md` §Dio cURL Interceptor §Header
  redaction, migrarlo. Si todo está, no migrar nada.
- [ ] **`05` → `roadmap.md`**: `grep` que el árbol §What's Unimplemented / TODO de
  `05` (Multiple fixture support, custom error handlers, performance assertions,
  OpenAPI/GraphQL gen, fixture replay) ya esté en `roadmap.md`. Lo que falte se migra a
  `roadmap.md` **antes** de comprimir `05` (si no, se pierde).
- [ ] **`00`/`01`**: confirmar que no hay nada único (esperado: nada). El criterio de
  éxito de `00` ("contract regressions detected in BE CI, not production") ya está en
  `PRD.md` §Success Metrics y §Goals.

No tocar `lib/` ni `example/` (regla de `AGENTS.md` §Critical Rules).

### Fase 1 — Comprimir cada archivo del memory-bank

Cada archivo conserva: su título, la línea `**Update this file when:**` (es guía útil
de mantenimiento), y reduce el cuerpo a propósito + puntero(s). El criterio es el
*contenido* (qué se conserva vs qué es derivable), no un número de líneas. Forma
objetivo abajo.

- [ ] **`00-projectbrief.md`**: 1-2 frases de qué es Testeador + punteros a `PRD.md`
  y `README.md`. Quitar Version/Status (vive en `pubspec.yaml`), Execution Models
  (vive en `architecture.md`/`README.md`), Key Constraint (vive en `AGENTS.md`
  §Critical Rules).
- [ ] **`01-product-context.md`**: 1 frase del problema + punteros a `PRD.md` y
  `PROBLEM.md`. Quitar todo el detalle de personas/goals (en `PRD.md`).
- [ ] **`02-system-patterns.md`**: lista compacta de las invariantes no-negociables
  (sequential, no-mocks, closure-capture, actor-per-log, fixture-per-flow, dual-mode)
  como *bullets de una línea cada uno* + puntero a `architecture.md` §Class
  Hierarchy/§Key Design Decisions para el detalle. Quitar los bloques de código de
  ejemplo (están en `architecture.md` §Example Walkthrough).
- [ ] **`03-tech-context.md`**: stack en 1 línea ("Dart ^3.11, dio, args, test; ver
  `pubspec.yaml`") + punteros a `architecture.md` §File Structure, a
  `architecture.md` "### CLI flags (standalone binary mode)" y a las nuevas
  subsecciones migradas en Fase 0. Quitar la tabla de flags (en
  `README.md`/`architecture.md`), el árbol de directorios (derivable +
  `architecture.md` §File Structure) y los ejemplos de CI.
- [ ] **`04-active-context.md`**: conservar **solo** estado transitorio no-derivable:
  - `## Current Focus` — el trabajo en vuelo / sin commitear en **forma resumida**
    (qué capacidad, 1 bloque de 3-5 bullets, sin el detalle por-archivo que vive en
    `git diff`). Mantener el puntero al plan en `~/.claude/plans/`.
  - `## Active Decision Points` — tal cual (es valioso y no-derivable).
  - `## Known Blockers` — tal cual.
  - `## Next Steps` — tal cual (compactado).
  - **Quitar:** el "Previous focus" acumulado (×4 bloques) → eso es historial, vive en
    `git log` / `CHANGELOG.md`. Dejar como mucho 1 línea: "Historial previo: ver
    `git log` y `CHANGELOG.md`."
  - **Quitar:** "Multi-Agent Collaboration Protocol" / "Recent Work Summary" /
    "Team Notes" si duplican `AGENTS.md` (el protocolo multi-agente ya está en
    `AGENTS.md` §Multi-Agent Collaboration Protocol).
- [ ] **`05-progress.md`**: conservar un **checklist de capacidades de alto nivel**
  (Core / Execution modes / MCP / Multidev / Codegen — un bullet por capacidad, sin
  sub-detalle por-archivo) + `## TODO` puntero a `roadmap.md` + `## Issues conocidos`
  (los 3 de hoy, compactados a 1 línea c/u). El historial detallado por fecha →
  `CHANGELOG.md` + `git log` (agregar puntero). Quitar Version History table (en
  `CHANGELOG.md`), Definition of Done, Test Coverage Status (derivable de `dart test`).
- [ ] **Reconciliar `04` ↔ `05`**: hoy ambos describen el mismo trabajo v0.3.0
  in-flight (web e2e, codegen, discover-and-pick) con palabras distintas. Tras
  comprimir, el `## Current Focus` de `04` y el checklist de `05` deben coincidir y no
  contradecirse.

### Fase 2 — Verificar consistencia de punteros

- [ ] Revisar [`AGENTS.md`](../../AGENTS.md) §Start Here / §Doc Map: el orden de
  lectura 00→05 sigue siendo válido (los archivos siguen existiendo). Confirmar que
  ningún puntero quedó apuntando a una sección eliminada.
- [ ] `grep` por enlaces rotos a `docs/memory-bank/*#seccion` en todo el repo (los
  pointer files `CLAUDE.md`/`GEMINI.md`/`.cursorrules`/`.windsurfrules`/copilot ya son
  redirects finos confirmados en revisión — no deberían requerir cambios).

## Forma objetivo (ejemplo: `00-projectbrief.md`)

```markdown
# Project Brief: Testeador

**Update this file when:** Project scope, name, or fundamental purpose changes.

---

Testeador es un paquete Dart que orquesta flujos de integración secuenciales para
contract testing: los tests del frontend corren sin cambios en el CI del backend y
detectan rupturas de contrato antes de producción.

- **Qué es / por qué:** ver [`docs/PRD.md`](../PRD.md) y [`README.md`](../../README.md).
- **Regla núcleo (no-mocks, sequential):** ver [`AGENTS.md`](../../AGENTS.md) §Critical Rules.
```

## Criterios de aceptación

- [ ] Los 6 archivos del memory-bank siguen existiendo.
- [ ] Reducción sustancial del tamaño total del memory-bank (referencia: ~80% menos
  desde las 814 líneas actuales). No es un gate exacto: la métrica real es ausencia de
  redundancia, no un conteo de líneas.
- [ ] Cero pérdida de información: cada fragmento único migrado existe ahora en su doc
  canónico (verificable con grep contra `architecture.md` y `roadmap.md`).
- [ ] (Checklist de reviewer, no gate automático) Ningún párrafo del memory-bank
  repite contenido de `PRD.md`, `PROBLEM.md`, `architecture.md`, `README.md`,
  `pubspec.yaml` o `CHANGELOG.md`.
- [ ] `04-active-context.md` conserva foco actual + decisiones + blockers + next steps.
- [ ] `05-progress.md` conserva el checklist de capacidades de alto nivel.
- [ ] Ningún enlace interno roto (grep de `](../` y `#` headings).
- [ ] Sin cambios en `lib/` ni `example/`.

## Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| Perder un gotcha/racional que solo vivía en 02/03 | Fase 0 migra **antes** de comprimir; grep de verificación en el destino |
| Romper el orden de lectura de `AGENTS.md` | Se conservan los 6 archivos y sus títulos; Fase 2 revalida punteros |
| Comprimir de más `04`/`05` y perder estado vivo | `04`/`05` solo pierden *historial* (a git/CHANGELOG), no estado actual ni TODO |

## Fuera de alcance

- Borrar o renombrar archivos del memory-bank (el usuario lo pidió explícitamente).
- Reestructurar `architecture.md` / `PRD.md` más allá de agregar las subsecciones
  migradas de Fase 0.
- Cambiar el protocolo de actualización del memory-bank en `AGENTS.md`.
