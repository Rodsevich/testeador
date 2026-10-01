# Mirador reference — supervision loop

## When to open mirador

Open mirador after every run that produces new evidence: new features, visual changes, or the first run of a scenario. Skip it when no new UI states were introduced (pure logic change) or when all steps crashed before any photo was taken — fix the crash first, then re-run.

## Starting mirador

```bash
dart run testeador_base:mirador review --port 4799 --once \
  --propose '<ai-pre-judgment-json>'
```

- `--once`: exits after processing all pending captures (no interactive loop). Reads `test_evidence/runs/current/`.
- `--propose '<json>'`: injects AI pre-judgment into the review panel as a starting point. The user can accept, override, or reject each suggestion.
- `--port 4799`: the loopback port for the web panel.

## --propose JSON shape

```json
{
  "schema": "testeador.propose/v1",
  "verdicts": [
    {
      "scenario": "checkout",
      "actor": "comprador",
      "slug": "pago_confirmado",
      "verdict": "replace_baseline",
      "confidence": 0.92,
      "rationale": "Price updated correctly after discount. Layout unchanged."
    }
  ]
}
```

Field descriptions:
- `scenario`: matches the flow's `name` (used as folder name under `test_evidence/`)
- `actor`: the `UiActor.name` value
- `slug`: the step's `description` field
- `verdict`: one of `replace_baseline`, `fix_code`, `fix_test`, `inconclusive`
- `confidence`: 0.0–1.0; used by mirador to sort and style suggestions
- `rationale`: one sentence explaining the verdict, shown to the human reviewer

Build the JSON by reading each `<actor>.manifest.json` in `test_evidence/runs/current/<scenario>/`, then judging each step's `intent` against the captures and diffs. See `references/verdicts.md` for the full AI judge protocol.

## Acting on verdicts

After mirador exits (or after `dart run testeador_base:mirador report`), read `test_evidence/baseline/<scenario>/verdicts.json`.

For each verdict:

| Verdict | What happened | Your action |
|---|---|---|
| `replace_baseline` | Mirador already copied the run capture over the baseline | Confirm the file is in place: `test_evidence/baseline/<scenario>/<actor>-<slug>.png` |
| `fix_code` | Evidence contradicts the step's intent | File a finding or open a task; this is a real bug |
| `fix_test` | UI is correct but the intent is stale | Update the step's `intent` (or `body` if interactions are wrong), then re-run |
| `inconclusive` | Not enough evidence to decide | Add a PR comment naming what evidence would unblock it; leave for human |

## Promote subcommand (headless / CI)

When mirador's web panel is not available:

```bash
dart run testeador_base:mirador promote \
  --scenario checkout \
  --actor comprador \
  --slugs pago_confirmado,resumen
```

Copies the named slugs from `test_evidence/runs/current/<scenario>/` to `test_evidence/baseline/<scenario>/`. Does not write to `verdicts.json` — record the verdict separately if needed.

## Report

```bash
dart run testeador_base:mirador report
```

Prints a verdict summary for the current run: counts by verdict type, any pending captures.

## HTTP API (loopback only)

Mirador binds to `127.0.0.1` only. These endpoints are useful for scripting or for the AI judge driving mirador programmatically:

| Method | Path | Description |
|---|---|---|
| `GET` | `/` | Web review panel |
| `GET` | `/queue` | Pending captures as JSON |
| `POST` | `/verdict` | Record a verdict |
| `POST` | `/capture` | Inject a capture |

## Other subcommands

```bash
dart run testeador_base:mirador capture          # take a fresh capture
dart run testeador_base:mirador ingest <run-dir> # load a run directory into review
```
