---
date: 2026-06-05
topic: compress-docs-in-place
---

# Comprimir la documentación sin reorganizarla

## What We're Building

La documentación del repo suma ~2.480 líneas repartidas en README, PRD, PROBLEM,
roadmap, architecture, AGENTS y un memory-bank de 6 archivos. Hay redundancia
fuerte: "qué es Testeador", la regla "no mocks", la ejecución dual y el glosario
aparecen repetidos en 3-4 archivos distintos. El objetivo es **recortar cada
archivo a la mitad eliminando esa redundancia**, manteniendo la estructura
actual, los nombres de archivo y el enfoque agent-agnostic. No se borra ni se
reorganiza nada: cada archivo sigue existiendo, solo que más corto y legible
para un humano que lee poco.

El motor del recorte es una regla de **fuente única de la verdad** (ya enunciada
en `AGENTS.md` §Guidelines pero no aplicada): cada hecho vive en UN solo archivo
canónico; los demás lo referencian con un link en vez de repetirlo.

## Why This Approach

Tres caminos considerados (el usuario eligió el conservador en los tres ejes):

- **Radical (README + AGENTS):** fundir todo en 1-2 archivos. Descartado: rompe
  el contrato agent-agnostic y la convención del memory-bank.
- **Moderado (4-5 docs, colapsar memory-bank a 1):** reorganiza. Descartado:
  cambia la estructura que el usuario quiere conservar.
- **Suave: comprimir cada archivo in situ (ELEGIDO).** Menos disruptivo, sin
  migraciones, sin links rotos hacia el exterior. La ganancia viene de borrar
  duplicación, no de mover cosas. Encaja con "solo achicar, sin cambiar enfoque".

## Key Decisions

- **Mantener los 6 archivos del memory-bank, los pointer files y toda la
  estructura.** Solo se recorta contenido. Rationale: el usuario quiere conservar
  el enfoque agent-agnostic.

- **Aplicar fuente única de la verdad como criterio de corte.** Mapa de
  propiedad canónica (quién es dueño de cada hecho; el resto referencia):

  | Hecho | Dueño canónico | Los demás |
  |---|---|---|
  | Qué es Testeador (1 párrafo) | README | linkean |
  | Quick start / CLI / MCP (uso) | README | — |
  | Reglas críticas (no mocks, secuencial, closure, transient TODO, pasar actors) | AGENTS.md | — |
  | Visión / personas / scope / requisitos de producto | PRD | mb 00/01 linkean |
  | Narrativa del problema | PROBLEM.md | PRD linkea |
  | Spec técnica completa + modelo de clases + **glosario** | architecture.md | mb 02/03, PRD glosario linkean |
  | Pains futuros | roadmap.md | PRD §future linkea |
  | Foco actual (estado vivo) | memory-bank/04 | único |
  | Qué funciona / progreso (estado vivo) | memory-bank/05 | único |

- **Targets de recorte por archivo** (~2.480 → ~1.100 líneas, ≈55% menos):

  | Archivo | Hoy | Target | Qué se corta |
  |---|---|---|---|
  | README.md | 355 | ~150 | rationale duplicado; deja uso/quick-start/CLI/MCP |
  | AGENTS.md | 80 | ~55 | funde las 3 tablas solapadas (Common Tasks / Doc Map) en una; deja reglas |
  | docs/PRD.md | 285 | ~110 | glosario→architecture; métricas/risks/open-questions a bullets; deja visión, ptr a problema, personas, scope, tabla FR |
  | docs/PROBLEM.md | 164 | ~120 | narrativa canónica del "porqué"; recorte de prosa |
  | docs/architecture.md | 655 | ~400 | ref. profunda; recorta prosa, conserva diagramas + glosario |
  | roadmap.md | 87 | ~60 | bullets |
  | mb/00-projectbrief | 35 | ~20 | qué+estado, linkea README/PRD |
  | mb/01-product-context | 58 | ~20 | linkea PRD/PROBLEM |
  | mb/02-system-patterns | 166 | ~30 | reglas-de-un-vistazo, linkea architecture |
  | mb/03-tech-context | 191 | ~30 | linkea pubspec + architecture |
  | mb/04-active-context | 145 | ~60 | tightening (estado vivo, se conserva) |
  | mb/05-progress | 219 | ~90 | colapsa listas done a bullets terso; quita sub-bullets verbosos |

- **Anti-regresión:** reforzar `AGENTS.md` §Guidelines con una línea explícita
  ("no repitas prosa entre archivos; edita el dueño canónico y linkea") para que
  la doc no vuelva a inflarse.

- **Tono humano:** frases cortas, menos tablas decorativas, sin encabezados de
  ceremonia tipo "Update this file when:" salvo donde aporten. Optimizar para
  lectura rápida.

## Open Questions

- ¿`docs/PROBLEM.md` (narrativa en español) debe quedar como el dueño canónico
  del "porqué" y el PRD solo linkearlo, o al revés? Propuesta: PROBLEM dueño,
  PRD resume en 2 líneas y linkea.
- ¿`architecture.md` (655→~400) es recorte suficiente o se quiere más agresivo?
  Es el único archivo "de referencia profunda on-demand", así que tolera más
  longitud que el resto.
- ¿Verificar que ningún pointer file externo ni el `.mcp.json`/recursos MCP
  (`testeador://docs/*`) dependan de secciones que se van a borrar antes de
  cortar? (chequeo durante el plan).
