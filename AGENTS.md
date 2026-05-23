# AGENTS.md

This file orients any AI coding agent working in this repository. It is intentionally thin: deeper context lives in the linked documents.

## Start Here

Read the following before any task, in this order:

1. [`docs/PRD.md`](docs/PRD.md) — product context, scope, goals, target users.
2. [`docs/memory-bank/00-projectbrief.md`](docs/memory-bank/00-projectbrief.md) — what this project is.
3. [`docs/memory-bank/01-product-context.md`](docs/memory-bank/01-product-context.md) — why it exists.
4. [`docs/memory-bank/02-system-patterns.md`](docs/memory-bank/02-system-patterns.md) — architecture patterns and key rules.
5. [`docs/memory-bank/03-tech-context.md`](docs/memory-bank/03-tech-context.md) — stack, dependencies, dev setup.
6. [`docs/memory-bank/04-active-context.md`](docs/memory-bank/04-active-context.md) — current focus and recent changes.
7. [`docs/memory-bank/05-progress.md`](docs/memory-bank/05-progress.md) — what works, what's left, known issues.
8. [`docs/architecture.md`](docs/architecture.md) — full technical specification (consult on demand).

## Critical Rules

These rules are non-negotiable. They are the contract between this codebase and any contributor — human or agent.

- **No mocks.** This package exists for integration contract testing. All HTTP calls must go to real APIs (staging, sandbox, or public test APIs). In-memory stores, local fakes, and mock objects for the system under test are forbidden — they defeat the purpose of contract testing.
- **Sequential execution only.** Steps within a `TestFlow` always run in declaration order. Never introduce concurrency within a flow.
- **Closure capture for context.** `TestStep.action` is a zero-argument function. Actors, repositories, and shared state are captured from the enclosing scope — not passed as parameters.
- **`TestFlowTransient` is a TODO marker.** No rollback is implemented. Do not document, recommend, or rely on it as if rollback works. It behaves identically to `TestFlowLasting` at runtime.
- **Always pass all actors to `Testeador(actors: [...])`.** This ensures their cURL logs are cleared before each flow and printed on failure.
- **Do not modify `lib/` or `example/` when writing documentation.** Documentation lives in `AGENTS.md`, `README.md`, `docs/PRD.md`, `docs/memory-bank/`, and `docs/architecture.md` only.

## Common Tasks

| Task | Where to look |
|---|---|
| Create a new test flow | [`docs/architecture.md`](docs/architecture.md) §TestFlow + §TestStep; mirror patterns in `example/pokebattle_rest/test/flows/` |
| Add a new Actor | [`docs/architecture.md`](docs/architecture.md) §Actor; mirror patterns in `example/pokebattle_rest/test/actors.dart` |
| Run the example suite | [`example/pokebattle_rest/README.md`](example/pokebattle_rest/README.md) |
| Configure CLI flags | [`README.md`](README.md) §CLI flags or [`docs/architecture.md`](docs/architecture.md) §Testeador |
| Understand the problem domain | [`docs/PROBLEM.md`](docs/PROBLEM.md) |
| Plan future work | [`roadmap.md`](roadmap.md) and [`docs/PRD.md`](docs/PRD.md) §Scope |

## Doc Map

| Question | File |
|---|---|
| Why does this project exist? | [`docs/PRD.md`](docs/PRD.md), [`docs/memory-bank/01-product-context.md`](docs/memory-bank/01-product-context.md), [`docs/PROBLEM.md`](docs/PROBLEM.md) |
| What is this project? | [`docs/memory-bank/00-projectbrief.md`](docs/memory-bank/00-projectbrief.md), [`README.md`](README.md) |
| How does it work technically? | [`docs/architecture.md`](docs/architecture.md), [`docs/memory-bank/02-system-patterns.md`](docs/memory-bank/02-system-patterns.md) |
| What is the tech stack? | [`docs/memory-bank/03-tech-context.md`](docs/memory-bank/03-tech-context.md), [`pubspec.yaml`](pubspec.yaml) |
| What is the current state? | [`docs/memory-bank/04-active-context.md`](docs/memory-bank/04-active-context.md), [`docs/memory-bank/05-progress.md`](docs/memory-bank/05-progress.md) |
| What is the public API? | [`lib/testeador.dart`](lib/testeador.dart), [`README.md`](README.md) |
| What's planned next? | [`roadmap.md`](roadmap.md), [`docs/PRD.md`](docs/PRD.md) §Scope |

## Multi-Agent Collaboration Protocol

When more than one agent (or human plus agent) works in this repository:

- **Read before write.** Before starting any task, read [`docs/memory-bank/04-active-context.md`](docs/memory-bank/04-active-context.md) to learn what other contributors are doing or have just done. Stale context produces conflicts and duplicated work.
- **Update memory in the same commit.** When you make a meaningful change (new feature, decision, status shift, dependency update), update [`docs/memory-bank/04-active-context.md`](docs/memory-bank/04-active-context.md) and — if the change is complete — append to [`docs/memory-bank/05-progress.md`](docs/memory-bank/05-progress.md) in the same commit or PR. Memory and code must move together.
- **Claim multi-commit tasks.** If a task spans more than one commit, add a `Claimed by: <agent-or-author> / <YYYY-MM-DD>` line under the relevant section in `04-active-context.md` so other agents do not duplicate work. Remove the line on completion.
- **Trust git for merges.** Do not hand-merge concurrent edits to memory-bank files. Resolve via git: most recent commit wins for transient state (`04-active-context.md`); conflicts in cumulative state (`05-progress.md`) are resolved by combining entries chronologically.
- **Commit messages communicate intent.** Reference the file or capability you touched. Future contributors read `git log` for context that the memory bank does not capture.

## Pointer Files for Specific Agents

Several agents auto-load instruction files with predetermined names. Each pointer file in this repository is a thin redirect to `AGENTS.md` and the memory bank — no agent-specific guidance lives in them. Add a new pointer file only when adopting a tool that requires its own filename.

| File | Read by |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Generic / cross-agent standard (primary) |
| [`CLAUDE.md`](CLAUDE.md) | Claude Code |
| [`GEMINI.md`](GEMINI.md) | Gemini CLI |
| [`.cursorrules`](.cursorrules) | Cursor |
| [`.windsurfrules`](.windsurfrules) | Windsurf |
| [`.github/copilot-instructions.md`](.github/copilot-instructions.md) | GitHub Copilot |

## Guidelines

- **Single source of truth.** When updating docs, edit the authoritative file and reference it from others. Do not duplicate prose across `README.md`, `AGENTS.md`, `docs/architecture.md`, `docs/PRD.md`, and the memory bank.
- **Keep the memory bank current.** After meaningful changes (new feature, dependency update, status change, decision), update [`docs/memory-bank/04-active-context.md`](docs/memory-bank/04-active-context.md) and [`docs/memory-bank/05-progress.md`](docs/memory-bank/05-progress.md). The memory bank is only useful if it reflects reality.
- **Agent-agnostic documentation.** This repository is meant to be navigable by any AI coding agent or human contributor. Do not introduce vendor-specific guidance outside of pointer files explicitly named after a tool (see the table above).
- **Verify before recommending.** If you are about to suggest a flag, function, or file path, confirm it exists in the current codebase. Memory and docs can drift.
