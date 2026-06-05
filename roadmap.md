# Roadmap

Pain points that drive the evolution of the tooling and the development process. Each is a real friction in speed, quality, or cross-team communication. Pains 2–4 are what testeador addresses today (see [docs/PRD.md](docs/PRD.md)); 5–7 are broader process goals.

- **Pain 2 — Single source of truth for contracts.** Contracts live in many places (docs, FE code, BE code, each team's tests); a change must be updated in each, breeding inconsistency and false safety. **Goal:** one source of truth, shared and consumed by all teams, so changes propagate automatically and are caught before production.

- **Pain 3 — Manual code adaptation on contract changes.** Teams hand-find and update every affected point; error-prone and unscalable. **Goal:** tooling that automates propagation (codegen, static validation, contract pipelines) so the machine catches errors, not the developer.

- **Pain 4 — Reactive cross-team communication.** Teams learn of breaking changes only when something fails in CI, staging, or production. **Goal:** make communication a natural side effect of the workflow (e.g. a backend PR that breaks frontend tests blocks the merge and notifies the affected team).

- **Pain 5 — No multidisciplinary feature process.** Features are built in silos; integration problems and contract bugs surface late, when fixes cost more. **Goal:** business, QA, frontend, and backend define the contract, acceptance criteria, and test cases together before any production code is written.

- **Pain 6 — Verbose, hard-to-consume user stories.** HUs carry redundant, ambiguous, or incomplete info. **Goal:** a minimal, sufficient format — **contract** (request/response), **Figma** link, **flow** (happy path + errors), **example** (a concrete case with real data).

- **Pain 7 — AI hallucinations from missing shared context.** Without a joint PRD, AI tools generate code/docs inconsistent with the real product. **Goal:** a living PRD per project centralizing scope, business logic, main flows, and architecture decisions — the base context for AI tools and the single reference for all teams.
