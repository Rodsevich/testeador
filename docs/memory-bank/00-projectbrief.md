# Project Brief: Testeador

**Update this file when:** Project scope, name, or fundamental purpose changes.

---

Testeador es un paquete Dart que orquesta flujos de integración secuenciales para
contract testing: los tests de integración del frontend corren **sin cambios** en el CI
del backend y detectan rupturas de contrato (renombre de campos, cambios de shape,
endpoints removidos) antes de que lleguen a producción.

- **Qué es y por qué existe:** [`docs/PRD.md`](../PRD.md), [`README.md`](../../README.md).
- **Reglas núcleo (no-mocks, ejecución secuencial, etc.):** [`AGENTS.md`](../../AGENTS.md) §Critical Rules.
- **Versión / estado de publicación:** [`pubspec.yaml`](../../pubspec.yaml), [`CHANGELOG.md`](../../CHANGELOG.md).
