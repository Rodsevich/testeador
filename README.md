# testeador

End-to-end testing for Dart and Flutter — user-journey flows with per-step
photos, declared intents, and an AI-ready visual review loop.

![pub.dev](https://img.shields.io/badge/pub.dev-unpublished-grey)
![Dart SDK](https://img.shields.io/badge/dart-%5E3.11.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Two packages, one workflow

| | [`testeador`](packages/testeador/) | [`testeador_base`](packages/testeador_base/) |
| --- | --- | --- |
| **Use when** | Your app has a Flutter UI | You need pure-Dart contract flows |
| **Test unit** | `UiTestFlow` — steps + photos + intents | `TestFlow` — steps + cURL logs |
| **Runner** | `flutter test` | `dart test` or a compiled binary |
| **Review** | `mirador review` — visual panel, brush verdicts | — |
| **Depends on** | `testeador_base` (transitively) | nothing Flutter |

Both packages live in this monorepo. `testeador` depends on `testeador_base`;
the reverse is never true.

## Quick start

**Flutter app (UI flows)** → see [`packages/testeador/README.md`](packages/testeador/README.md).

**Dart backend (contract flows)** → see [`packages/testeador_base/README.md`](packages/testeador_base/README.md).

## Install AI skills

```bash
dart run testeador_base:testeador skills install
```

Writes `.claude/skills/testeador/` into the current project, inserts a managed
block in `AGENTS.md`, and merges the MCP server entry into `.mcp.json`. Any AI
assistant that reads `AGENTS.md` then knows to write `UiTestFlow`s and open
mirador automatically when you ask for a feature.

## Docs

- [AGENTS.md](AGENTS.md) — entry point and critical rules for all AI assistants
- [Architecture](packages/testeador_base/docs/architecture.md) — full technical spec
- [PRD](packages/testeador_base/docs/PRD.md) — product context, goals, personas
- [Memory bank](packages/testeador_base/docs/memory-bank/) — structured project history

## License

MIT — see [LICENSE](LICENSE).
