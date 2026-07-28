---
title: "feat: record bracket — MCP tools, CLI, gap report & docs"
type: feat
date: 2026-06-05
part: 5 of 5
---

## feat: record bracket — MCP tools, CLI, gap report & docs (PR-5) - Standard

> Part 5 of the split from [2026-06-05-feat-contract-discovery-from-app-traffic-plan.md](2026-06-05-feat-contract-discovery-from-app-traffic-plan.md). The user-facing surface that ties the engine together.

## Dependencies

- **PR-4** (the full capture → diff → generate core).

## Overview

Expose the bracket workflow: MCP `start_recording` / `stop_and_generate` (gated) and an equivalent `testeador record` CLI, both sharing the PR-2…PR-4 core. Emit a gap report and document the feature (marionette as the **optional** AI-driver).

## Technical Approach

### MCP tools (`lib/src/mcp/tools/capture_tools.dart`)

- `start_recording` — attach to (or launch) the app + open capture (`TrafficCapture.open`). Returns a recording id + status.
- `stop_and_generate` — `takeExchanges()` → `GapAnalysis` → emit units + gap report.
- Gated by a `TESTEADOR_MCP_ENABLE_*` env var, registered exactly like `multidev_tools.dart` (`registerTool` + `okResult`/`errResult`, wired in `tools.dart`).
- The driver in between is **indistinct**: human taps or AI via marionette's own MCP tools. Capture is passive and independent of marionette.

### CLI (`testeador record start|stop`)

- Mirrors the MCP bracket for manual use; shares the same core (the project's dual MCP+CLI pattern, as `discover` has).

### Gap report (`lib/src/capture/gap_report.dart` — small; inline-able into `gap_analysis.dart` if trivial)

- JSON artifact + human summary, grouped by microservice (exercised / covered / missing).
- Returned in the MCP/CLI response and written as a `*.gap.json` artifact.

### Lifecycle

- Capture always closes and the app/Chrome process is killed on failure (`finally`, as in `web_capture.dart`).

### Docs (review #4, #10 + AGENTS.md single-source rule)

- README: "Discover tests from real usage" section (MCP + CLI); marionette documented as the **optional** AI-driver, not required for human-driven capture.
- `architecture.md`: new `capture/` subsystem, `EndpointId`, manifest schema change, sequence diagram. Single canonical statement for deterministic ordering (no duplication).
- memory-bank `04-active-context.md` + `05-progress.md`.
- Example walkthrough: drive an example app → generate a missing contract test.

## Acceptance Criteria

- [ ] MCP `start_recording`/`stop_and_generate` (gated) + equivalent CLI share one core.
- [ ] Driver-agnostic passive capture; generated artifacts have no marionette/`vm_service` runtime dependency.
- [ ] Human + JSON gap report per microservice; capture-blind reported, never "fully covered".
- [ ] Capture + child processes always cleaned up on failure.
- [ ] README, `architecture.md`, memory-bank `04`/`05` updated; example walkthrough runs.
- [ ] `dart analyze` clean; `very_good test` green.

## References

- `lib/src/mcp/tools/multidev_tools.dart:11-177` (tool pattern + gating), `lib/src/mcp/tools/tools.dart:27-39`
- `lib/src/multidev/web_capture.dart` (`finally` cleanup pattern)
- AGENTS.md (memory-bank moves with code; single-source-of-truth docs)
