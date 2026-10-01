# Feature: testeador AI docs + skills installer

Locator: `odd/tasks/testeador-ai-docs-and-skills.md` · Engram mirror: `odd/testeador-ai-docs-and-skills/tasks`

## Objective

When a user asks an AI to build a feature in an app that uses testeador, the AI (without being told) will:

1. Write or extend a testeador `UiTestFlow` that proves the feature is correct.
2. Run the flow, which produces one photo per step with its declared intent.
3. Start mirador so the user can check the feature visually and send changes back with brushes and notes.
4. Read the user's verdicts and act on them.

Docs stay short for humans and complete for AIs. A single CLI command installs the AI knowledge into a consumer project.

## Problem (evidence from exploration, 2026-09-30)

- Root `AGENTS.md`, `CLAUDE.md` and `README.md` link to `docs/*` and `roadmap.md`. Those files live in `packages/testeador_base/docs/`, so every link is broken. The MCP `testeador://docs/*` resources resolve against the workspace root and return not-found for the same reason.
- The root README describes only `testeador_base` (backend `TestFlow`). Nothing documents `UiTestFlow`, `UiTestStep.intent`, evidence, `knownDefects`, mirador or the verdict loop, and `packages/testeador` has no README.
- `.mcp.json` runs `testeador:testeador`, but the Flutter package `testeador` declares no executables (`mirador` and `testeador` belong to `testeador_base`). This is probably why the testeador MCP server failed to connect. To verify in T0.2.
- `bin/testeador.dart` hardcodes `_version = '0.3.0'`, but the pubspec says 0.4.0.
- MCP templates and scaffolds cover only the backend `TestFlow`. No scaffold exists for `UiTestFlow`/`TestSuite`, and no tool exists for mirador or evidence.
- Nothing installs skills, agent guidance or MCP config into a consumer project. The only agent that mentions testeador is `.claude/agents/fe-dart-integration-test-author.md`.
- The mirador feedback loop (brushes → `POST /verdict` → `verdicts.json` + stdout on `review --once`) works, but only by pull, and no AI-facing doc describes it.
- No consumer-style example uses `UiTestFlow` + `TestSuite` + mirador. The best reference today is a unit test: `packages/testeador/test/src/ui_test_flow_test.dart`.

## Scope

In scope:
- Fix doc links and the MCP entry.
- Add one reference example.
- Write short human docs.
- Write one AI skill with its references.
- Add a `skills install` CLI.
- Close the gaps in the mirador loop that block the AI.
- Dogfood the result.

Out of scope:
- `TestFlowTransient` rollback.
- pub.dev publishing.
- New evidence and drift algorithms.
- A push channel from mirador to the agent (not needed, see T5.1).

## Constraints

- Single source of truth. Each fact lives in one owner file, and the others link to it. The skill references ARE the complete AI documentation. Human docs summarize and link, and never duplicate.
- The no-mocks rule, sequential steps and closure capture are unchanged (`AGENTS.md`).
- Complex scripts are written in Dart (user rule). The installer is Dart code in the existing CLI.
- Artifacts are in English. Commits are Conventional Commits with the user's sole authorship and no AI attribution.
- Keep it lazy: one skill (progressive disclosure through `references/`), not one skill per topic. The installer command is idempotent, with no framework.

## Decisions (defaults, override if wrong)

- D1: **One skill, `testeador`.** It holds `SKILL.md` (the trigger plus the feature loop) and three files under `references/`: `authoring.md` (eloquent flows), `mirador.md` (supervision loop) and `verdicts.md` (moved from `docs/verdict-agent.md` and linked back).
- D2: **Install targets.** The skill goes to `.claude/skills/testeador/`. A managed block with begin and end markers goes into `AGENTS.md`, which other agents (Codex, Cursor, Gemini) read through their pointer files. The testeador server entry is merged into `.mcp.json`.
- D3: **Skill sources ship inside `testeador_base/lib/src/skills/`** as Dart string constants, reusing the pattern from `lib/src/mcp/templates/`. This way `dart run` and a compiled exe can both reach them without resolving asset paths.
- D4: **Auto-trigger mechanism.**
  - The skill description triggers on "implement/change/fix a feature or screen in a Flutter app that depends on testeador".
  - The AGENTS.md block restates the rule "every feature ⇒ UiTestFlow + mirador" in three lines.
  - No hooks. Add them only if dogfooding (T6.1) shows the skill does not trigger.
- D5: **The AI waits for the user's review without new plumbing.** It runs `mirador review` as a background process and reacts when the process exits (it prints the verdicts), then reads `verdicts.json`.

## Checks and TDD

- TDD: **on**. Source: the orchestrator config ("Strict TDD Mode: enabled"). Runners:
  - `dart test` in `packages/testeador_base`.
  - `flutter test` in `packages/testeador`.
- Docs-only tasks get a structural readback plus a link check: `rg -o '\]\(([^)#]+)' -r '$1'` on the changed markdown, confirming each target exists.
- Code tasks: `dart analyze` (zero lints, the repo convention) and the package tests.

## Delivery

- Branch: `feat/ai-docs-skills`, created from `master` before the first commit.
- Forecast: about 2,000 authored changed lines across the whole feature, which is above the 400-line delivery budget.
- Strategy: `ask-on-risk`. Before the first commit, ask once whether to chain as `stacked-to-main` or `feature-branch-chain`.
- Each stage below is one PR slice.

## Stages and tasks

Each stage can be shipped on its own and leaves the repo coherent.

### Stage 0 — Unbreak what exists (small, inline)

- [x] T0.1 **Fix root doc links.** Repoint the links in root `AGENTS.md`, `CLAUDE.md` and `README.md` to `packages/testeador_base/docs/...` and `packages/testeador_base/roadmap.md`. Do not move the files: moving them churns history, and the MCP docs resources need their own fix anyway.
  - Route: inline (3 files, mechanical).
  - Check: link check.
- [x] T0.2 **Fix the MCP entry and resource resolution.**
  - Verify the root cause first.
  - Fix `.mcp.json` to run the server from `testeador_base`: the executable lives there, and `dart run` needs the package in the resolved graph. Check whether a transitive dependency works; if not, see T4.3.
  - Make `testeador://docs/*` resolve through the package root instead of the workspace root.
  - Sync `_version` with the pubspec.
  - Route: inline or delegated, depending on how many resource files are involved.
  - TDD: a failing test for docs-resource resolution.
- [x] T0.3 **Refresh `memory-bank/04-active-context.md` and `05-progress.md`.** Add the work that shipped but was never recorded: mirador ingest/review/promote/capture/report, `UiTestFlow`, intent, `knownDefects`. Fix the stale date.
  - Route: inline.

### Stage 1 — Reference example (the thing every doc points at)

- [x] T1.1 **Create `packages/testeador/example/`.** It is a tiny Flutter app with two screens and one backend call to a real public API (no mocks). It contains:
  - `TestSuite.entry` with one fixture ("world") and two actors.
  - One `UiTestFlow` with 4–6 eloquent `UiTestStep`s, each with an `intent`.
  - One `knownDefects` entry that is demonstrated.
  - A committed baseline under `test_evidence/baseline/`.
  - Route: delegated writer (several new files). TDD: the flow itself is the test; the RED state is "no baseline / step fails".
- [x] T1.2 **Record the working commands in the example README** (5 lines): run the flow, `mirador review`, `mirador promote`, and ingest from patrol.
  - Check: run each command once and paste the observed output into the task evidence.

### Stage 2 — Human docs (short, simple)

- [ ] T2.1 **Write `packages/testeador/README.md`** (≤120 lines):
  - What it is, in 3 lines, and the loop as a diagram: feature → flow → photos → mirador → verdict.
  - A 5-minute quick start copied from the example.
  - Where to go next (links only).
  - Route: inline.
- [ ] T2.2 **Rewrite the root `README.md` as a two-package map.**
  - It explains which package to depend on (`testeador` for Flutter UI, `testeador_base` for pure-Dart contract flows) and the one command to install AI skills (Stage 4).
  - The current backend content moves to `packages/testeador_base/README.md`, which is the real owner of that content.
  - Route: delegated writer (2 files, content move).
- [ ] T2.3 **Add a "Mirador" section to `testeador_base/docs/architecture.md`.** This is the owner of endpoints, flags, the evidence layout and verdict kinds. Everything else links here.
  - Route: inline.

### Stage 3 — AI knowledge: the `testeador` skill (complete for AIs)

- [ ] T3.1 **Write `SKILL.md`**, following the `skill-creator` rules for frontmatter and a trigger description. Its body is the **feature loop contract**:
  1. Find the closest existing `UiTestFlow` and extend it before creating a new one.
  2. Write or extend steps first (RED).
  3. Implement the feature.
  4. Run the flow and check that every step has a photo.
  5. Start `mirador review` in the background (with `--propose` holding the agent's pre-judgment) and tell the user the URL.
  6. When mirador exits, read the verdicts and apply them: `fix_code` / `fix_test` / `replace_baseline` → `mirador promote` / `variants` / `explain`.
  7. Never close a feature without at least one photo per new UI state.

  It also carries hard rules: no mocks, no hiding a defect (use `knownDefects` with a reason), and no auto-promoting baselines without a user verdict.
- [ ] T3.2 **Write `references/authoring.md`, the "eloquent testflows" guide:**
  - One flow per user journey, not per widget.
  - `description` in the user's voice ("Ana adds the second Pokémon").
  - `intent` states what the photo must prove, and is falsifiable by a reviewer.
  - Every step ends in a visually distinct state.
  - Actors are named personas, and the fixture is the "world".
  - Choosing viewport presets.
  - Shared state through closure capture.
  - `knownDefects` versus fixing.
  - Drift marks (`!`, `~new`, `~crash`) and what to do with each.
  - One good and one bad example, both taken from the Stage 1 example.
- [ ] T3.3 **Write `references/mirador.md`:** commands and flags, `--propose` JSON shape, background-run pattern, how to read `verdicts.json`, the live `capture` and `report` commands for debugging a running app. It links to architecture for the endpoints (no duplication).
- [ ] T3.4 **Write `references/verdicts.md`.**
  - Move the content of `docs/verdict-agent.md` into it. The old path keeps a one-line pointer.
  - Keep `verdict-schema.json` where it is and link to it.
  - Route for Stage 3: delegated writer (4 files), and the writer loads `skill-creator`.
  - Check: structural readback, and confirm every API name cited exists (`rg` in `lib/`).

### Stage 4 — Skills installer (`testeador skills install`)

- [ ] T4.1 **Embed the Stage 3 files as Dart constants** under `testeador_base/lib/src/skills/` (D3).
  - Add one generator or consistency test that fails if the embedded constants drift from the markdown sources. The markdown stays editable, and the test enforces the sync.
  - TDD: RED on drift.
- [ ] T4.2 **Add the `skills install` subcommand** to `bin/testeador.dart`, with flags `--project-root`, `--dry-run` and `--force`. It:
  - Writes `.claude/skills/testeador/**`.
  - Inserts or updates the managed block in `AGENTS.md`, creating the file if it is missing. It never touches content outside the markers.
  - Merges the `testeador` entry into `.mcp.json`, keeping other servers and never overwriting a user-edited testeador entry without `--force`.
  - Prints a per-file report: created, updated or unchanged.
  - Is idempotent: a second run changes nothing.
  - TDD: temp-dir tests for create, update, idempotency, a foreign `AGENTS.md` kept, and `.mcp.json` merged.
  - Route: delegated writer.
- [ ] T4.3 **Make the command reachable from a Flutter consumer** that depends only on `testeador`.
  - Verify `dart run testeador_base:testeador skills install` from the example app.
  - If a transitive executable is refused, add a thin forwarding `bin/` plus `executables:` to `packages/testeador`.
  - Check: run it in `packages/testeador/example` and observe the files.
- [ ] T4.4 **Add `skills status`** (read-only): report whether the installed copy is stale versus the package version. Only add it if T4.2 does not already cover it cheaply through `--dry-run`. Default: skip.

### Stage 5 — Mirador loop gaps for the AI

- [ ] T5.1 **Validate the full loop by hand on the example:** run → review with `--propose` → paint → send → the background process exits → read `verdicts.json` → promote. Record what breaks.
- [ ] T5.2 **Fix the gaps that T5.1 finds.** Likely candidates:
  - A stable machine-readable stdout (JSON) on `review --once` exit.
  - A free-form "change request" note surfaced to the agent.
  - `--propose` accepted from a file path.
  - Found while building T1.1, each one is boilerplate the skill would otherwise have to teach:
    - Real HTTP under `flutter_test` needs three workarounds: `HttpOverrides.global = null`, a `waitFor` helper that pumps real time, and `idleTimeout = Duration.zero` on the actor's `HttpClient`. Absorb them in the package, e.g. a real-HTTP Dio factory and a wait helper.
    - `setUpEvidence` does not load `MaterialIcons`, so icons render as empty squares.
    - `slugify` drops accents (`Pokémon` becomes `pok_mon`).
    - `promote` needs one call per actor with the slugs spelled out. Add `--all`.
    - Spanish log strings in `packages/testeador`, e.g. the `knownDefects` notice. This breaks the English-artifact rule.
  - Only what T5.1 shows as needed. TDD per fix.
- [ ] T5.3 **Add the `scaffold_ui_flow` MCP tool and a `ui_flow` template** (`UiTestFlow` + `TestSuite` + actor). This way scaffolding matches the UI-first product. Update `testeador://templates/*`.
  - Route: delegated writer. TDD.

### Stage 6 — Dogfood (acceptance of the whole objective)

- [ ] T6.1 In a fresh copy of the example with skills installed, open a new AI session and ask for a small feature, with no mention of tests or mirador. Pass when the AI, unprompted:
  - (a) extends or creates a `UiTestFlow` with intents,
  - (b) runs it with a photo per step,
  - (c) starts mirador and gives the URL,
  - (d) acts on the verdicts.

  Record the observed transcript highlights. If the skill does not trigger, tune the description or the AGENTS block first, and consider hooks (D4) only after that.
- [ ] T6.2 **Update `.claude/agents/fe-flutter-e2e-test-author.md` and `fe-flutter-feature-orchestrator.md`** so they defer to the `testeador` skill when the project depends on testeador.
- [ ] T6.3 **Update the memory bank** (04/05) and close this document.

## Acceptance criteria

- No broken relative links in root or package docs. The testeador MCP server connects from this repo.
- A human can go from nothing to a first photo + mirador review in ≤5 minutes using `packages/testeador/README.md`.
- `testeador skills install` is idempotent, keeps foreign content, and works from a Flutter consumer.
- T6.1 passes.

## Progress

- 2026-09-30: exploration done, plan created.
- 2026-09-30 Stage 0 done on `feat/ai-docs-skills` (RDD on; TDD on, runner `dart test`):
  - T0.1 `8f70deb` (inline). 25 broken links repointed across AGENTS/CLAUDE/GEMINI/README/.cursorrules/.windsurfrules/copilot-instructions. The link check now reports 0 broken.
  - T0.2 `3aba33d` (inline, 2 source files). Root cause confirmed: the repo root has no `pubspec.yaml`, so `dart run testeador:testeador` failed with "Found no pubspec.yaml". `.mcp.json` now runs `dart run packages/testeador_base/bin/testeador.dart mcp`, and the patrol `PROJECT_ROOT` prefix was fixed too. `resolveDocFile` + `testeadorBasePackageRoot` serve the docs from the package root. TDD: RED (undefined functions), then GREEN, with 5 new tests. The full `dart test` suite passes (275), and `dart analyze` reports 0 issues. An end-to-end MCP stdio handshake from the root read all 3 `testeador://docs/*` resources. `_version` is now 0.4.0.
  - Finding for T4.3: from `packages/testeador`, `dart run testeador_base:testeador --version` works.
  - T0.3 (inline): memory-bank 04/05 updated.
  - Review assess for `ae765e6..3aba33d`: risk medium, `review_due=false`, reason `under_budget`, so it stayed pending in the slice.
  - After T0.3 (`a48608e`) the slice reached its budget (`slice_budget_reached`, medium, 14 files / 437 lines).
    - Consent: **granted**.
    - One lens, `review-reliability`: **approved**, acknowledged, authority burned (lineage `review-ec37be6a52d7d195`). The reviewed boundary is now `a48608e`.
    - Local-only change to make that possible: `.atl/`, `.codegraph/` and `devtools_options.yaml` added to `.git/info/exclude`, so the preflight is not blocked on untracked tool noise.
  - Non-blocking follow-ups from the review, not scope:
    - R3-001: `.mcp.json` relative paths assume the client spawns from the repo root. That holds for Claude Code; revisit if another client needs it.
    - R3-002: a `late tmp` teardown masks a setUp failure. Trivial.
    - R3-003: add a test for the one-level-up candidate in `resolveDocFile`. Fold it into T5.3 or a later touch of `resources.dart`.

- 2026-09-30 Delivery: the user chose **feature-branch-chain**.
  - The tracker branch is `feat/ai-docs-skills`, at base `ae765e6`.
  - Child slices: `feat/ai-docs-skills-s0` (Stage 0) and `feat/ai-docs-skills-s1` (Stage 1, based on s0).
  - Nothing has been pushed. Push and PR creation are the user's call.
- 2026-09-30 T1.1 (delegated writer; trigger: several new files):
  - Created `packages/testeador/example/`:
    - A PokéAPI team builder.
    - `TestSuite` with `PokeFixture` and two actors, `ana` (light) and `ben` (dark).
    - One `UiTestFlow` with 5 intent steps.
    - A demonstrated `knownDefects` entry: the abilities-row `RenderFlex` overflow.
    - A 10-PNG baseline.
  - Real HTTP, no mocks.
  - Evidence:
    - RED: the first run gave 10 `~new` captures.
    - `mirador promote` ran once per actor.
    - GREEN: "All tests passed!" with no drift marks.
    - Parent spot check: `flutter analyze` reports 0 issues and `flutter test` gives +2 green.
  - Finding for T4.3: `dart run testeador_base:mirador` works from the example, where `testeador_base` is only a transitive dependency.

- 2026-09-30 T1.2 (inline): `packages/testeador/example/README.md`.
  - Ingest from patrol was dropped: the example has no patrol run, so the command could not be verified.
  - Observed:
    - `mirador review --port 4799` serves `test_evidence`, and the queue has 0 items on a clean run (unchanged captures are skipped, `review.dart:210`).
    - With `colorSchemeSeed` changed: tests pass and the queue has 10 items with 5 marks each.
    - With a label renamed: the flow crashes, so that one is not used as the README example.
  - Incident: port 4771 was already held by a `mirador review` from another project (stabilitas). A broad `pkill -f 'mirador.*review'` probably killed it. Lesson for the skill (T3.3): always pass `--port` and kill only your own PID.

- 2026-09-30 Stage 1 review (`feat/ai-docs-skills-s1`, lineage `review-185e82a339b81516`):
  - Risk: medium, 503 lines, 19 files.
  - One lens (`review-reliability`): **approved**, authority burned.
  - Advisory (non-blocking):
    - R3-001 (WARNING): `PokeFixture.load()` uses a plain `Dio()` without `idleTimeout = Duration.zero`; the same idle-socket pending-timer risk that Trainer mitigates at lines 35-40. → Candidate for T5.2.
    - R3-002 (WARNING): `_search()` awaits `widget.api.find(name)` with no try/catch; a non-200/404 response throws `DioException` unhandled. → Candidate for T5.2.
    - R3-003 (SUGGESTION): "I open the add screen" step has no programmatic assertion; only the photo proves the route change. → Candidate for T5.2 or T6.x.
    - R3-004 (SUGGESTION): `expect($('$foundName #25'), ...)` interpolates a nullable String?; should use the hardcoded literal `'pikachu #25'`. → Candidate for T5.2.
    - R3-005 (SUGGESTION): README `mirador review` example omits `--port`; duplicates the lesson already in the task log. → Fixed in T2.1 or T2.2.
- 2026-09-30: created `feat/ai-docs-skills-s2` from s1. Starting Stage 2.

## Next step

Stage 2 on `feat/ai-docs-skills-s2`: T2.1 `packages/testeador/README.md`, T2.2 root + testeador_base READMEs, T2.3 Mirador section in architecture.md.
