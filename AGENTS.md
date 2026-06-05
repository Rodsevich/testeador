# AGENTS.md

Entry point for any AI agent or human contributor. Intentionally thin: deeper context lives in the linked documents.

## Start Here

Read in this order before any task:

1. [`docs/PRD.md`](docs/PRD.md) — product context, scope, goals, users.
2. [`docs/memory-bank/`](docs/memory-bank/) — structured project memory, files `00` → `05`.
3. [`docs/architecture.md`](docs/architecture.md) — full technical spec (consult on demand).

## Critical Rules

Non-negotiable. The contract between this codebase and any contributor.

- **No mocks.** This package exists for integration contract testing. All HTTP calls must go to real APIs (staging, sandbox, or public test APIs). In-memory stores, local fakes, and mock objects for the system under test are forbidden — they defeat the purpose.
- **Sequential execution only.** Steps within a `TestFlow` always run in declaration order. Never introduce concurrency within a flow.
- **Closure capture for context.** `TestStep.action` is a zero-argument function. Actors, repositories, and shared state are captured from the enclosing scope — not passed as parameters.
- **`TestFlowTransient` is a TODO marker.** No rollback is implemented. Do not document, recommend, or rely on it as if rollback works. It behaves identically to `TestFlowLasting` at runtime.
- **Always pass all actors to `Testeador(actors: [...])`.** This ensures their cURL logs are cleared before each flow and printed on failure.
- **Do not modify `lib/` or `example/` when writing documentation.** Docs live in `AGENTS.md`, `README.md`, `docs/PRD.md`, `docs/memory-bank/`, and `docs/architecture.md` only.

## Doc Map

| Need | File |
| --- | --- |
| Use the package / quick start / CLI / MCP | [`README.md`](README.md) |
| Why it exists (problem narrative) | [`docs/PROBLEM.md`](docs/PROBLEM.md) |
| Product scope, personas, requirements | [`docs/PRD.md`](docs/PRD.md) |
| Technical spec, class model, glossary | [`docs/architecture.md`](docs/architecture.md) |
| Current state & what's done | [`docs/memory-bank/04-active-context.md`](docs/memory-bank/04-active-context.md), [`docs/memory-bank/05-progress.md`](docs/memory-bank/05-progress.md) |
| What's planned | [`roadmap.md`](roadmap.md) |
| New flow / actor / fixture | [`docs/architecture.md`](docs/architecture.md) + mirror `example/pokebattle_rest/test/` |

## Multi-Agent Collaboration

When more than one contributor (agent or human) works here:

- **Read before write.** Check [`docs/memory-bank/04-active-context.md`](docs/memory-bank/04-active-context.md) first to see what others are doing.
- **Update memory in the same commit.** On a meaningful change, update `04-active-context.md` and — if complete — append to `05-progress.md` in the same commit. Memory and code move together.
- **Claim multi-commit tasks** with a `Claimed by: <author> / <YYYY-MM-DD>` line under the relevant section in `04-active-context.md`; remove it on completion.
- **Trust git for merges.** Don't hand-merge concurrent memory-bank edits.

## Pointer Files

Several tools auto-load instruction files by name. Each is a thin redirect to this file — no agent-specific guidance lives in them. Add a new one only when adopting a tool that requires its own filename.

| File | Read by |
| --- | --- |
| `AGENTS.md` | Generic / cross-agent (primary) |
| `CLAUDE.md` | Claude Code |
| `GEMINI.md` | Gemini CLI |
| `.cursorrules` | Cursor |
| `.windsurfrules` | Windsurf |
| `.github/copilot-instructions.md` | GitHub Copilot |

## Guidelines

- **Single source of truth.** Each fact lives in one canonical file (see the Doc Map). Never repeat prose across `README.md`, `AGENTS.md`, `docs/architecture.md`, `docs/PRD.md`, and the memory bank — edit the owner and link to it. This keeps docs short and prevents drift.
- **Keep memory current.** After meaningful changes, update `04-active-context.md` and `05-progress.md`. The memory bank is only useful if it reflects reality.
- **Verify before recommending.** Confirm a flag, function, or file path exists in the current codebase before suggesting it. Docs can drift.
