# Verdict agent — reference prompt

This document is the reference contract for the **AI judge** that analyzes a
`testeador` evidence run. Any agent (Claude Code, a CI bot, a custom script
driving an LLM) that follows it produces interchangeable results. Verdicts
must validate against [`verdict-schema.json`](verdict-schema.json).

## Inputs

For each scenario/actor pair, read:

1. `test_evidence/runs/current/<scenario>/<actor>.manifest.json` — the
   structural source of truth: every step's `intent`, `status`, diff score
   and artifact references. **Never parse file names**; trust the manifest.
2. **Diff triptychs first** (`diff.image`, `*.diff.png`): a single image with
   `baseline | actual | changed-pixels-highlighted` — usually all the visual
   context you need for a drifted capture.
3. Raw captures and baselines, when the triptych is not enough or does not
   exist (`~new`, `~crash`, `~device` captures).
4. Attachments (`attachments.http` curl files, logs), to correlate what the
   backend did with what the UI shows.

## Task

For every step in the manifest, decide **one** verdict:

| Verdict | Meaning | Action you take |
|---|---|---|
| `fix_code` | The evidence contradicts the step's `intent`, or something outside this flow's changes looks broken (collateral damage). | Report it (with severity). Do **not** touch baselines. |
| `fix_test` | The UI is correct but the step's declared `intent` (or its interactions) is outdated — the test lies, not the app. | Report which intent/step to update. |
| `replace_baseline` | The drift is an **intentional** consequence of the change under review. | Copy the run capture over `test_evidence/baseline/<scenario>/<actor>-<slug>.png` **and** append your verdict (with rationale) to `verdicts.json` in that folder. Both land in the PR diff — that is the human audit trail. |
| `inconclusive` | You cannot decide with the available evidence. | Escalate to a human (PR comment/label). Never guess, never act. |

## Rules

- **A `~new` capture is never silently promoted.** First-run captures require
  an explicit `replace_baseline` verdict from you (adoption) or a human
  running `flutter test --update-goldens`. Before adopting, verify the
  capture actually satisfies the step's `intent` — adopting a broken screen
  poisons every future comparison.
- **Judge against the `intent`, not against your taste.** The intent is the
  step's contract. If the intent itself is stale, that is `fix_test`.
- **Marks prioritize, they don't judge.** `!!!` means "look here first", not
  "this is broken". A 1-pixel `!` can be a critical missing button; a `!!!!`
  can be an intentional redesign.
- **Discount environment mismatch.** If the manifest's `environment`
  (Flutter version, platform) differs from the baseline's canonical CI
  environment, low-mark drift is likely rendering noise — set
  `environmentMismatch: true` and lean toward `inconclusive` rather than
  `fix_code` for subtle differences.
- **`~crash` captures + `skipped` steps**: the run already failed (red).
  Your job is to explain *what the screen shows* at the moment of the crash
  and whether the exception matches the visual state — that context goes in
  the rationale of a `fix_code` verdict.
- **`~device` captures** (patrol e2e) have no baseline and no marks: treat
  them as visual evidence for intent-checking only.
- **Batch replacements need a note.** If you issue more than ~5
  `replace_baseline` verdicts in one run, say so explicitly in your summary
  so reviewers know a visual redesign is being self-approved wholesale.
- **Optional deep audit**: sample a few zero-mark captures and verify they
  still satisfy their intent — a baseline adopted wrongly in the past never
  drifts, yet is wrong.

## Output

1. Append verdicts to
   `test_evidence/baseline/<scenario>/verdicts.json`
   (create it as `{"schemaVersion": 1, "verdicts": []}` if missing),
   validating against [`verdict-schema.json`](verdict-schema.json).
2. Perform the baseline copies your `replace_baseline` verdicts demand.
3. Produce a human summary: verdict counts, every `fix_code` finding with
   severity, every `fix_test` target, and anything `inconclusive` with what
   evidence would unblock it.
