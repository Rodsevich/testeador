---
date: 2026-06-05
topic: compiled-test-runners
---

# Binarios de test compilados y persistidos para consumo cross-repo

## What We're Building

Una capacidad para **compilar una suite de testeador en binarios standalone, persistirlos en el repo vía Git LFS, y exponerlos a pipelines de otros repos mediante una GitHub Action reusable**. El objetivo es que un repo consumidor pueda ejecutar los tests de integración de un flujo **sin instalar el SDK de Dart/Flutter, sin compilar, y sin conocer la mecánica interna de testeador**: solo referencia la action, pasa los tags relevantes y obtiene un binario listo para correr.

La primitiva técnica base ya existe (`compile_suite_exe` → `dart compile exe`), pero hoy se detiene en producir un binario para el host y reportar su path. Esta feature agrega: compilación multiplataforma reproducible localmente, persistencia versionada del artefacto, manifiesto con metadata e integridad, y un mecanismo de consumo cross-repo de bajo acoplamiento.

## Why This Approach

El modelo actual de testeador asume que **el repo consumidor compila el binario en su propio CI** (vía paquete pub o el MCP). Eso exige Dart SDK en el runner del consumidor y paga el costo de compilación en cada corrida. Para los objetivos elegidos —consumidor sin SDK, pipelines más rápidos y máxima simplicidad para el consumidor— se invierte el modelo: **se pre-compila una vez en el repo de origen y se distribuye el binario terminado**.

Se descartaron alternativas en cada decisión:

- **CI matrix multiplataforma** para compilar: descartado a favor de **Docker (Linux) + nativo (macOS)** porque el usuario prioriza reproducibilidad local sin depender de infraestructura de CI para producir los artefactos.
- **Commit directo / GitHub Releases** para persistir: descartado a favor de **Git LFS**, que mantiene los binarios "en el repo" sin inflar el historial git (~200MB por versión entre las dos plataformas).
- **Un binario por flujo pre-filtrado / híbrido**: descartado a favor de **un binario por suite con filtrado en runtime** (`--include-tags`), que reusa el comportamiento ya existente del CLI y minimiza la cantidad de artefactos.
- **curl directo / git submodule** para consumir: descartado a favor de una **GitHub Action reusable** que encapsula la descarga y ejecución; el consumidor solo hace `uses: <org>/testeador/run-tests@<ref>`.
- **Script/Makefile / extender `compile_suite_exe`** para orquestar: descartado a favor de una **nueva tool MCP `build_suite_runners`**, consistente con el patrón "todo es tool MCP" del proyecto, reusando la lógica de compilación existente.

## Key Decisions

- **Motivación = consumidor sin Dart SDK + velocidad de pipeline + simplicidad para el consumidor.** El versionado inmutable del contrato NO es un driver; el foco es operativo (descargar y correr).
- **Targets de plataforma: Linux x64 + macOS arm64.** `dart compile exe` no cross-compila, así que cada binario debe producirse en su plataforma nativa.
- **Generación local reproducible: Docker `dart:stable` para Linux x64, `dart compile exe` nativo para macOS arm64.** Sin dependencia de CI para producir los artefactos.
- **Persistencia: Git LFS.** Se trackea `build/runners/**` en `.gitattributes`; el árbol git guarda punteros, el contenido va al store LFS. Junto a los binarios, un `manifest.json` **plano** (no LFS) con: versión, commit fuente, plataforma, sha256 de cada binario, flows/tags disponibles y fecha de compilación.
- **Granularidad: un binario por suite, filtrado de flujo en runtime** vía `--include-tags`/`--include-flows`. El consumidor elige el flujo relevante al ejecutar; no se pre-filtra en tiempo de compilación.
- **Consumo: GitHub Action reusable** (`uses: <org>/testeador/run-tests@<ref>`) con inputs (tags, flows, plataforma auto-detectada). Por dentro resuelve la plataforma y descarga el binario (raw/media URL de LFS), hace `chmod +x` y lo ejecuta.
- **Orquestación: nueva tool MCP `build_suite_runners`.** Inputs aproximados: `suite_path`, `platforms[]`, `out_dir` (default `build/runners`). Responsabilidades: compilar ambas plataformas (Docker + nativo), `strip` opcional para reducir tamaño, calcular sha256, escribir `manifest.json`, dejar todo listo para `git add`. Reusa la lógica de `compile_suite_exe`.

## Open Questions

- **Ubicación canónica y naming.** ¿`build/runners/<platform>/<suite-name>` es la convención definitiva? ¿El nombre del binario deriva del basename del entrypoint o se parametriza?
- **`.gitignore` vs `.gitattributes`.** Hoy `.gitignore` excluye `build/`. Hay que decidir si `build/runners/` se exceptúa explícitamente o si el directorio canónico vive fuera de `build/` para evitar fricción con LFS.
- **`.pubignore` y publicación.** Hoy `.pubignore` excluye `*.exe`. Confirmar que los binarios persistidos no se incluyan en el paquete pub publicado (no deberían inflar el package).
- **Materialización LFS en el consumidor.** Validar que la raw/media URL de GitHub sirve el contenido real del objeto LFS (no el puntero) para `curl` dentro de la action, y definir el pinning de versión (`@<tag>` vs `@<sha>`).
- **Strip y tamaño.** ¿`strip` se aplica siempre? ¿Cuánto reduce realmente (~100MB base)? Impacto en el costo de LFS storage/bandwidth.
- **Plataformas adicionales.** Linux arm64 / Windows quedaron fuera del alcance inicial; confirmar que no se necesitan a corto plazo (YAGNI).
- **Frescura del artefacto.** ¿Cómo se garantiza que el binario commiteado refleja el estado actual de la suite? ¿Un check en CI que recompila y compara sha, o queda como disciplina manual?
- **GitLab / otros CI.** La action reusable es específica de GitHub Actions. ¿Se necesita un snippet equivalente para GitLab u otros, o GitHub cubre el alcance inicial?
