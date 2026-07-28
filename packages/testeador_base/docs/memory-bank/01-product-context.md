# Product Context: Why Testeador Exists

*Update when: problem statement, user needs, or value proposition changes.*

Frontend contract tests normally run only in frontend CI, so a backend change can break the contract silently until production. Rewriting the tests with backend tooling defines the contract twice; the copies drift. Mocks hide breaks entirely. Testeador's answer: define the contract once (in the frontend's tests) and run it unchanged in backend CI against real APIs.

Users and their success conditions, value proposition, and goals are documented canonically in [PRD.md](../PRD.md) (§Target Users, §Goals). Full problem narrative with diagrams: [PROBLEM.md](../PROBLEM.md). Roadmap pains 2–4: [roadmap.md](../../roadmap.md).
