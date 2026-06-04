# Active Context: Current Work & State

**Update this file when:** New work begins, priorities shift, or blockers are resolved.

**Last Updated:** 2026-05-30

---

## Current Focus

**Web e2e + admin panel — sin commitear (2026-05-30).**

`WebDevice` pasó a ser un target Patrol-web **manejado** (no solo superficie de
evidencia): la fleet corre `patrol test --device chrome` contra una app Flutter web, y
un nuevo **admin panel** web en el ejemplo Serverpod es el sistema bajo prueba.

- testeador: `TargetDevice` gana `patrolDeviceId` + `patrolExtraArgs()`; `patrolCommandFor()`
  es la única fuente de verdad del comando (android serial / ios udid / web chrome+flags).
  `--web-viewport` toma un objeto JSON, no `WxH`. Suite del paquete 93 green / 1 skip.
- Ejemplo: admin panel (`main_admin.dart` + `lib/admin/`), endpoint `admin.reset()/seedPlayers/seedBattle`,
  y e2e `admin_overview_test.dart` **1/1 green** en Chrome headless (directo y vía `PatrolRunner.runOn`).
- Desbloqueada la resolución `meta` del ejemplo Flutter: se quitó `testeador` de la app
  Flutter y la orquestación host se movió a `pokebattle_serverpod_server/tool/` + `bin/`.

(Historial previo —codegen `TestInjector`, discover-and-pick, MCP server, fixes v0.3.0—
vive en `git log` y [`CHANGELOG.md`](../../CHANGELOG.md). El inventario de capacidades
está en [`05-progress.md`](05-progress.md).)

## Active Decision Points

- **Granularidad de Patrol.** La API de Patrol vive dentro de bloques `patrolTest` (no hay
  canal remoto para el host). testeador invoca Patrol una vez por "agent flow" por device
  como subprocesos paralelos, y toma screenshots desde el host (`adb`/`xcrun simctl`). Si
  un Patrol futuro expone un driver remoto, se puede cambiar `PatrolRunner` sin tocar los flows.
- **In-memory store en el `_server` Serverpod.** El template salta Postgres y guarda estado
  en `InMemoryStore` para bootear en segundos. Cambiar a DB real si se necesita persistencia.

## Known Blockers

- **TestFlowTransient rollback:** diferido (predates streaming work).
- **Publicación a pub.dev:** diferida. La API multidev agrega deps (`image`) y expectativas
  de plataforma (`adb`/`xcrun simctl` en PATH) que deben documentarse antes de publicar.

## Next Steps (provisional)

1. Verificar end-to-end en dos emuladores booteados.
2. Capturar `evidence/<label>/composite.png` de muestra para el README.
3. Considerar documentar `DeviceFleet` en `docs/architecture.md` cuando la API se estabilice.
4. Roadmap v1.0 pendiente (rollback de TestFlowTransient, prep pub.dev).
