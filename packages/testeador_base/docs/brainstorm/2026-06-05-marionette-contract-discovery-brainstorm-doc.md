---
date: 2026-06-05
topic: marionette-contract-discovery
---

# Descubrimiento de tests de contrato faltantes ejercitando la app real (marionette)

## What We're Building

Una capacidad para **descubrir qué tests de integración de contrato faltan**, ejercitando la app Flutter real y observando qué endpoints/microservicios del backend depende. El driver de la app es **indistinto**: un humano tocando el simulador, o una IA manejándola vía [`marionette_flutter`](https://pub.dev/packages/marionette_flutter) (que expone tap/enter/scroll/screenshot/logs sobre una app viva por VM service). La captura del tráfico HTTP es **pasiva** — observa las llamadas salgan de donde salgan, sin importar quién maneje.

A partir de esa observación, testeador extrae la **superficie de contrato real** que la app ejercita, la cruza contra la cobertura existente (vía el manifest de codegen) y **genera las unidades de test de integración que faltan** — una por endpoint descubierto sin cobertura, sembrada con la request/response observada como contrato. El entregable **no es un flow terminado**: son tests de integración que luego se incluyen en un `TestFlow` reusando el pipeline `discover`/`TestInjector` ya existente (capturar → `--pick` → inyectar). Marionette es andamiaje **dev-time only**; los tests generados son HTTP puros y corren en CI sin marionette.

## Why This Approach

La misión de testeador es **contract testing HTTP** (el contrato se define una vez en el FE, el BE lo corre en CI contra APIs reales, con cURL para reproducir). Manejar la UI es ortogonal a esa misión, y "UI/visual/mobile testing" es Non-Goal explícito. La clave de este enfoque es que **la UI es el medio, no el sujeto**: no testeamos la UI, la usamos para *descubrir el contrato* que la app realmente consume. El artefacto producido es HTTP puro — exactamente lo que testeador ya corre — así que el Non-Goal se respeta y la misión se potencia en vez de diluirse.

El valor ataca una fricción real de adopción: hoy, para saber qué tests escribir, el autor tiene que descubrir a mano qué endpoints toca cada journey (leer código, mirar el network tab) y luego identificar cuáles no están cubiertos. Esto automatiza ese descubrimiento usando la app de verdad.

Alternativas descartadas (con su razón):

- **`MarionetteActor` en flows (UI + contrato en el mismo test):** descartado. Expande el scope a UI testing (Non-Goal), se solapa con Patrol en `multidev`, mete marionette en el **runtime de CI** (el BE necesitaría la app Flutter corriendo), y rompe el determinismo HTTP secuencial. Patrol ya es mejor fit para e2e de UI.
- **Proxy MCP (re-exponer las tools de marionette):** descartado como feature en sí. Es indirección sobre el MCP propio de marionette, no produce ningún artefacto testeador, no ataca ninguna métrica de la misión. (Puede usarse internamente como detalle de implementación cuando la IA maneja la app, pero no es el entregable.)
- **Grabar y reproducir el journey como flow (record-and-replay de taps):** descartado. El objetivo no es registrar interacciones de UI sino identificar cobertura de endpoints faltante. El journey es desechable; lo que importa es la superficie de contrato que revela.

Sobre la captura del tráfico se eligió un modelo de **dos backends bajo una abstracción común** (`TrafficCapture`), porque la app hace sus llamadas con su propio cliente HTTP — el `CurlInterceptor` de testeador no las ve:

- **Native (Android/iOS/desktop):** HTTP profiler del VM Service (`ext.dart.io.getHttpProfile`), el mismo canal que usa marionette y el tab Network de DevTools. Captura requests + responses con headers y bodies, sin proxy ni instrumentar la app. Dio corre sobre `dart:io HttpClient`, así que funciona.
- **Web:** dominio **Network de CDP** (Chrome), porque en web no hay `dart:io`. Sinergia con `multidev` (`web_capture.dart` ya maneja Chrome) y marionette soporta web. Se maneja la UI web con marionette y se captura el tráfico vía CDP desde la misma instancia.

Se descartó un **proxy local (mitmproxy-style)** por el costo de certificados/config por plataforma, aunque cubriría web y native por igual. **Web entra desde el arranque** (no se difiere), por eso los dos backends se diseñan juntos.

## Key Decisions

- **Objetivo = descubrir tests de contrato faltantes, no grabar UI.** La unidad de valor es la cobertura de endpoints/microservicios del backend; el journey de UI es el medio desechable para revelar esa superficie.
- **Entregable = unidades de test de integración (una por endpoint sin cobertura), no un flow.** Se incluyen luego en un `TestFlow` vía el pipeline `discover`/`TestInjector` existente (`--pick` / inyección). Reúso, no reinvención.
- **Driver indistinto + captura pasiva.** Humano en el simulador o IA vía marionette: la captura observa el tráfico igual. Esto justifica el modelo de orquestación bracket.
- **Orquestación = bracket (MCP `start_recording` / `stop_and_generate`) + comando CLI.** Las tools MCP cubren el flujo con agente; el CLI cubre el uso manual/interactivo. Consistente con el patrón dual del proyecto (`discover` tiene MCP + CLI). La captura abre/cierra en el bracket; quién maneja la app en el medio es indistinto.
- **Captura dual bajo `TrafficCapture`:** VM Service HTTP profiler (native) + CDP Network (web), ambos desde el día uno, alimentando un modelo normalizado de "intercambio capturado".
- **Baseline de cobertura = manifest de codegen.** El gap se calcula leyendo el manifest (qué cubren los tests capturados) en vez de re-ejecutar la suite. Implica enriquecer el manifest para que registre **qué endpoints cubre cada test** (hoy guarda fqId/nombre/tags).
- **Marionette es dev-time only; el output es HTTP puro.** Los tests generados corren en CI sin marionette ni VM service. El Non-Goal de UI testing se mantiene intacto.
- **Assertions conservadoras y borrador.** Se siembran status code + presencia/forma de campos clave desde la response observada; el humano refina. Como todo codegen, el output es un punto de partida, no final.

## Open Questions

- **Cómo entran los endpoints al manifest de codegen.** El manifest hoy no registra cobertura de endpoints. ¿Se puebla por análisis estático en build time (frágil: URLs Dio se arman en runtime), por una corrida de captura única que lo anota, o por anotación del autor? Esta es la decisión técnica más fina del baseline.
- **Identidad/templating de endpoints.** ¿Cómo colapsar `/users/123` y `/users/456` en `/users/{id}`? Heurística de path-templating necesaria para no generar tests duplicados ni perder el agrupamiento por endpoint. ¿Se incluye el status code y/o el método en la identidad?
- **Qué exactamente se genera por endpoint faltante.** ¿Un `TestStep` que reproduce la llamada + asserta el contrato observado? ¿Un test capturable (estilo shim de `package:test`) listo para `--pick`? ¿Cómo se mapea cada llamada al `Actor` correcto (qué Dio/base URL) y se aplica la redacción de headers?
- **Granularidad de assertions.** ¿Hasta dónde sembrar desde la response? Status + presencia de campos vs. shape completo vs. golden. Evitar assertions exact-match frágiles.
- **Mapeo llamada → microservicio.** Si hay múltiples backends/base URLs, ¿cómo se agrupan los endpoints por servicio para reportar cobertura por microservicio (no solo por endpoint)?
- **Límites del VM Service profiler.** Tamaño máximo de body capturado, truncamiento, soporte de streaming/SSE/websockets, y comportamiento con `package:http` vs `dio` (ambos sobre `dart:io`, validar).
- **Conexión y ciclo de vida.** ¿Testeador lanza la app + marionette, o se conecta a una app ya corriendo (VM service URI)? ¿Cómo coexiste con la sesión MCP de marionette que el agente ya tiene abierta?
- **Reporte de gap.** Además de generar los tests, ¿se emite un reporte legible (endpoints ejercitados / cubiertos / faltantes por microservicio) como artefacto de revisión?
- **Web parity.** Confirmar que el modelo normalizado de `TrafficCapture` reconcilia bien lo que da el VM profiler (native) vs CDP Network (web) — formatos, timing, bodies — sin fugas de abstracción.
