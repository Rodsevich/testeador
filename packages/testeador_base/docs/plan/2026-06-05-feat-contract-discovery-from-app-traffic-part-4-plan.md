---
title: "feat: coverage gap analysis, secret redaction & test-unit generation"
type: feat
date: 2026-06-05
part: 4 of 5
---

## feat: coverage gap analysis, secret redaction & test-unit generation (PR-4) - Extensive

> Part 4 of the split from [2026-06-05-feat-contract-discovery-from-app-traffic-plan.md](2026-06-05-feat-contract-discovery-from-app-traffic-plan.md). The business-logic + security-sensitive core: diff, redaction, codegen.

## Dependencies

- **PR-1** (`EndpointId`, manifest `coveredEndpoints` round-trip).
- **PR-2** and/or **PR-3** (`CapturedExchange` as diff input — PR-2 alone is enough to ship web-only).

## Overview

Turn captured exchanges into the deliverable: diff exercised vs. covered endpoints, redact secrets, and generate one integration test unit per uncovered endpoint. Units feed the existing `discover`/`TestInjector --pick` pipeline; `--assemble-flow` optionally emits a full `TestFlow`.

## Technical Approach

### `GapAnalysis` (`lib/src/capture/gap_analysis.dart` — renamed from `coverage_diff` per review #5)

- Exercised set = `EndpointId`s from captured exchanges; covered set = `EndpointId`s from manifest `coveredEndpoints`.
- `gap = exercised − covered`, grouped by service/microservice.
- **Dedup repeated calls** to one endpoint: prefer the **last 2xx** response as the seed; collapse `401 → token-refresh → retry` to the successful call (G6/G9).
- **Cold-start (D1):** if covered is `null`/un-annotated, do **not** auto-generate the whole surface — list candidates and warn. **The automatic capture-and-annotate backfill is deferred to a follow-up** (review: highest-risk dependency). For v1, coverage is populated by manual annotation or left empty (cold-start). A `testeador record annotate` backfill command is out of scope here.

### `secret_redactor` (`lib/src/capture/secret_redactor.dart`) — security gate, own reviewable unit (review #6)

- Strip secrets from generated **source** (it gets committed to git — worse than the log case):
  - Request `authorization`/`cookie` + configurable header keys → parametrized via runtime config reference, never a literal.
  - Response-body keys matching `token|secret|password|*_token` → redacted/shape-only matcher.
  - **No redacted value is ever emitted as an assertion.**
- Reuse the `redactHeaders` convention; coordinate the runtime config reference with `TesteadorRuntimeConfig` from the sibling runners plan (G7/D7).

### `test_unit_emitter` + `contract_unit` template

- `lib/src/mcp/templates/contract_unit.dart` (style of `contract_test.dart`); `lib/src/capture/test_unit_emitter.dart`.
- One unit per uncovered endpoint; **conservative assertions**: status code + top-level response key presence/type (no exact-value, no full golden). Partial exchanges → stub-assertion unit with a TODO.
- Imports **`package:testeador/testeador.dart` only** — no marionette/`vm_service` at runtime. Assert this automatically in emitter tests (review #7).
- Map exchange → `Actor` by host; missing host ⇒ a **flagged Actor stub**, never a compile failure (G7).
- **Re-run safety (simplified — review V3):** do **not** overwrite an existing unit by default; warn with the endpoint identity. `--force` overwrites. **No drift-diff / source parsing** in this PR.
- Optional `--assemble-flow`: trivial — `emitInjectedFlow(units)`. Not a separate deliverable.

## Testing (fixtures, not mocks)

- [ ] `GapAnalysis`: fixture exchange sets + manifest coverage → expected gap; dedup last-2xx; 401-retry collapse; service grouping.
- [ ] `secret_redactor`: exhaustive — header keys, response-body key patterns, the "no redacted literal as assertion" rule. **Automated no-secret CI check**, not just an assertion that can be skipped.
- [ ] `test_unit_emitter`: generated source imports testeador-only; missing-host → stub; no-overwrite default; partial → stub assertion.
- [ ] E2E: generated units compile and run **green against the real backend** (no mocks of the SUT).

## Acceptance Criteria

- [ ] Gap = exercised − covered, grouped by service; dedup + 401-collapse correct.
- [ ] Generated source contains **no literal secrets** (request + response); enforced by an automated check.
- [ ] One unit per uncovered endpoint, testeador-only imports, conservative assertions, Actor-by-host (missing ⇒ flagged stub).
- [ ] No-overwrite default + `--force`; `--assemble-flow` emits a `TestFlow` via `emitInjectedFlow`.
- [ ] Cold-start never silently auto-generates the whole surface.
- [ ] `dart analyze` clean; pure-logic units 100%; `very_good test` green; memory-bank `04` updated.

## References

- `lib/src/discovery/picker.dart:12-186`, `lib/src/discovery/flow_emitter.dart:60-90`, `lib/src/mcp/templates/injected_flow.dart:18-42`
- `lib/src/mcp/templates/contract_test.dart`
- Shared config: `docs/plan/2026-06-05-feat-build-suite-runners-plan.md` (Component 3, `TesteadorRuntimeConfig`)
