---
name: testeador
description: >
  Activate when writing, running, or acting on UiTestFlow evidence in the testeador monorepo.
triggers:
  - keywords: [UiTestFlow, UiTestStep, UiActor, TestSuite, mirador, testeador]
    description: Working with testeador test flows or the mirador review CLI
  - keywords: [intent, baseline, verdict, replace_baseline, fix_code, fix_test, promote]
    description: Acting on visual evidence or AI judge verdicts
references:
  - path: references/authoring.md
    when: Writing or extending a UiTestFlow
  - path: references/mirador.md
    when: Running mirador or acting on verdicts
  - path: references/verdicts.md
    when: Judging evidence as the AI verdict agent
---

# Testeador skill

## Feature loop

Follow this loop for every feature that touches UI:

1. **Find or create the flow.** Look for an existing `UiTestFlow` for the scenario first; extend it before creating a new one. One flow per scenario.
2. **Write steps before implementation.** Commit `description` and `intent` for every new UI state before writing any app code. The intent is a contract, not a post-hoc caption.
3. **Implement the feature.**
4. **Run the flow.**
   ```bash
   flutter test test/<flow_file>.dart
   ```
5. **Open mirador with AI pre-judgment.**
   ```bash
   dart run testeador_base:mirador review --port 4799 --once \
     --propose '<json>'
   ```
   See `references/mirador.md` for the `--propose` JSON shape.
6. **Act on verdicts.** Read `test_evidence/baseline/<scenario>/verdicts.json` after mirador exits. See `references/mirador.md` for per-verdict actions.
7. **Every new UI state gets at least one photo.** Never skip a step to avoid a capture.

## Hard rules

- **No mocks.** All HTTP calls go to real APIs (staging, sandbox, public endpoints). Use `HttpOverrides.global = null` in `setUpAll`.
- **No hiding a defect.** Known issues go in `knownDefects` with a reason string; never delete a step to suppress a photo.
- **No silent promotion.** `replace_baseline` requires an AI judge verdict in `verdicts.json` or explicit human action in mirador.
- **Intents are pre-implementation contracts.** Write them before the code, not after. An intent written post-hoc is a description, not a contract.

## Quick reference

```
test_evidence/runs/current/<scenario>/   ← gitignored, per-run
test_evidence/baseline/<scenario>/       ← committed, versioned
```

For authoring patterns (fixture, actor, PatrolTester, knownDefects) → `references/authoring.md`
For mirador usage and verdict actions → `references/mirador.md`
For AI judge instructions → `references/verdicts.md`
