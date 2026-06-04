# Product Context: Why Testeador Exists

**Update this file when:** Problem statement, user needs, or value proposition changes.

---

El frontend escribe tests que definen los contratos de la API, pero solo corren en su
propio CI. Si el backend rompe el contrato, la falla es silenciosa y reactiva: se
descubre tarde (CI del frontend o producción). Testeador hace que esos mismos tests
corran en el CI del backend, con una única fuente de verdad y **sin mocks** (los mocks
ocultan rupturas reales).

- **Problema, personas, value proposition, goals:** [`docs/PRD.md`](../PRD.md).
- **Narrativa del problema (con diagramas):** [`docs/PROBLEM.md`](../PROBLEM.md).
- **Pains de producto que motivan la evolución:** [`roadmap.md`](../../roadmap.md).
