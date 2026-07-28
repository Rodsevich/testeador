---
title: "docs: compress documentation in place removing cross-file redundancy"
type: refactor
date: 2026-06-05
---

## docs: compress documentation in place removing cross-file redundancy — Standard

## Overview

Recortar la documentación del repo de ~2.480 a ~1.100 líneas (≈55% menos) sin
borrar ni reorganizar archivos. Cada archivo sigue existiendo con su mismo nombre
y rol; solo se elimina la redundancia entre archivos y se acorta la prosa para un
humano que lee poco. El criterio de corte es la **fuente única de la verdad**:
cada hecho vive en un archivo canónico y los demás lo referencian con un link.

Brainstorm origen:
[2026-06-05-compress-docs-in-place-brainstorm-doc.md](../brainstorm/2026-06-05-compress-docs-in-place-brainstorm-doc.md)

## Problem Statement / Motivation

"Qué es Testeador", la regla **no mocks**, la ejecución dual (`dart test` / CLI),
y el glosario están repetidos en 3-4 archivos (README, PRD, memory-bank,
architecture). Esa duplicación: (1) hace la doc pesada e ilegible para humanos,
(2) deriva (las copias se desincronizan), y (3) viola la propia regla §Guidelines
de `AGENTS.md` que ya pide fuente única de la verdad pero no se aplica.

## Proposed Solution

Editar cada archivo in situ. Donde un archivo repite un hecho que pertenece a
otro, reemplazar el texto por una línea de referencia con link. Conservar en cada
archivo solo su "porción" canónica (ver mapa abajo) más lo que sea estado vivo
único (memory-bank 04/05).

### Mapa de propiedad canónica (motor del recorte)

| Hecho | Dueño canónico | Los demás |
|---|---|---|
| Qué es Testeador (1 párrafo) | README | linkean |
| Quick start / CLI / MCP (uso) | README | — |
| Reglas críticas (no mocks, secuencial, closure, transient TODO, pasar actors) | AGENTS.md | — |
| Visión / personas / scope / requisitos | docs/PRD.md | mb 00/01 linkean |
| Narrativa del problema ("porqué") | docs/PROBLEM.md | PRD resume 2 líneas + linkea |
| Spec técnica + modelo de clases + **glosario** | docs/architecture.md | mb 02/03, PRD glosario linkean |
| Pains futuros | roadmap.md | PRD §future linkea |
| Foco actual (estado vivo) | memory-bank/04 | único, se conserva |
| Qué funciona / progreso (estado vivo) | memory-bank/05 | único, se conserva |

### Pre-chequeos de seguridad (ya verificados en research)

- `lib/src/mcp/resources.dart:65-82` sirve `docs/architecture.md`, `AGENTS.md` y
  `docs/PRD.md` **completos por path** (sin anclas a secciones). Comprimir su
  contenido no rompe las resources MCP, siempre que los 3 archivos sigan
  existiendo. ✅ El plan los conserva.
- Pointer files (`CLAUDE.md`, `GEMINI.md`, `.cursorrules`, `.windsurfrules`,
  `.github/copilot-instructions.md`) son redirects finos a `AGENTS.md`. No se
  tocan salvo que cambie la lista de lectura en AGENTS.md (entonces se actualizan
  en espejo).

## Technical Considerations

- **Sin cambios de código.** Solo markdown bajo `AGENTS.md`, `README.md`,
  `docs/`. Respeta la regla de `AGENTS.md`: "Do not modify `lib/` or `example/`
  when writing documentation."
- **Reader journey (humano que lee poco):** entrada por README (qué es + cómo se
  usa en 1 pantalla) → AGENTS.md para reglas si va a tocar código → architecture
  on-demand para profundidad. Verificar que ese recorrido funcione sin saltos
  rotos tras el recorte.
- **Anti-regresión:** añadir a `AGENTS.md` §Guidelines una línea explícita: "No
  repitas prosa entre archivos; editá el dueño canónico y linkeá." Para que la
  doc no se vuelva a inflar.
- **Links internos:** tras recortar, validar que ningún link relativo apunte a
  una sección (`#anchor`) que se eliminó.

## Acceptance Criteria

Recorte por archivo (target orientativo, prioridad = eliminar duplicación):

- [ ] **README.md** (355 → ~150): conserva qué-es (1 párr), quick start, CLI ref,
  sección MCP. Borra rationale/problema duplicado (→ PROBLEM/PRD).
- [ ] **AGENTS.md** (80 → ~55): funde las tablas solapadas "Common Tasks" + "Doc
  Map" en una sola tabla de navegación. Conserva las reglas críticas íntegras.
  Añade la línea anti-redundancia en §Guidelines.
- [ ] **docs/PRD.md** (285 → ~110): glosario eliminado (→ architecture). Métricas,
  riesgos y open-questions colapsados a bullets. Conserva visión, puntero a
  PROBLEM (2 líneas), personas, scope, tabla FR.
- [ ] **docs/PROBLEM.md** (164 → ~120): queda como dueño canónico del "porqué".
  Recorte de prosa, sin perder la narrativa.
- [ ] **docs/architecture.md** (655 → ~400): única referencia profunda; tolera más
  longitud. Recorta prosa redundante, conserva diagramas y el glosario canónico.
- [ ] **roadmap.md** (87 → ~60): pains a bullets.
- [ ] **docs/memory-bank/00-projectbrief.md** (35 → ~20): qué + estado; linkea
  README/PRD.
- [ ] **docs/memory-bank/01-product-context.md** (58 → ~20): linkea PRD/PROBLEM.
- [ ] **docs/memory-bank/02-system-patterns.md** (166 → ~30): reglas-de-un-vistazo;
  linkea architecture.
- [ ] **docs/memory-bank/03-tech-context.md** (191 → ~30): linkea pubspec +
  architecture.
- [ ] **docs/memory-bank/04-active-context.md** (145 → ~60): tightening; conserva
  estado vivo.
- [ ] **docs/memory-bank/05-progress.md** (219 → ~90): listas "done" a bullets
  tersos; quita sub-bullets verbosos. Conserva qué-funciona/qué-falta.

Validación global:

- [ ] Total de líneas de doc baja a ~1.100 (`wc -l` sobre el set de archivos).
- [ ] Ningún hecho del mapa aparece desarrollado en más de un archivo (su dueño).
- [ ] Los 3 archivos servidos por MCP (`architecture.md`, `AGENTS.md`, `PRD.md`)
  siguen existiendo y se leen coherentes standalone.
- [ ] Ningún link interno roto (chequeo de anchors eliminados).
- [ ] `lib/` y `example/` intactos (`git diff --stat` no los lista).
- [ ] El recorrido README → AGENTS → architecture queda navegable sin lagunas.

## Success Metrics

- ≈55% menos líneas de documentación.
- Cada hecho con un único dueño (cero duplicación de prosa).
- Un humano puede entender qué es y cómo correr el proyecto leyendo solo el README.

## Dependencies & Risks

- **Riesgo: perder contexto útil al recortar.** Mitigación: el recorte mueve
  hechos al dueño canónico, no los borra; los archivos vivos (04/05) se conservan.
- **Riesgo: el memory-bank queda "demasiado fino" para agentes.** Mitigación: 02/03
  pasan a punteros explícitos a architecture/pubspec — el agente sigue teniendo el
  camino, solo sin la copia.
- **Sin dependencias externas.** No requiere builds ni tests de código.

## References & Research

- MCP doc resources: `lib/src/mcp/resources.dart:65-82` (sirve por path, sin anclas).
- Regla fuente-única ya enunciada: `AGENTS.md:77` (§Guidelines).
- Regla "no tocar lib/ ni example/ al documentar": `AGENTS.md:27`.
- Inventario actual (líneas): README 355, AGENTS 80, PRD 285, PROBLEM 164,
  architecture 655, roadmap 87, memory-bank 00-05 = 35/58/166/191/145/219.
