---
title: "feat: compile suite runners into committed binaries for cross-repo pipelines"
type: feat
date: 2026-06-05
---

## feat: compile suite runners into committed binaries for cross-repo pipelines - Standard

> Brainstorm: [docs/brainstorm/2026-06-05-compiled-test-runners-brainstorm-doc.md](../brainstorm/2026-06-05-compiled-test-runners-brainstorm-doc.md)
> Technical review applied: 2026-06-05 (simplicity + VGV + split agents). Verified facts inline.

## Overview

Add the ability to **compile a testeador CLI suite into standalone native binaries, persist them in the repo via Git LFS, and consume them from other repos' pipelines through a reusable GitHub Action** — with no Dart/Flutter SDK on the consumer side, no compilation step in the consumer's CI, and no knowledge of testeador internals beyond "download and run".

The technical primitive already exists (`compile_suite_exe` → `dart compile exe`), but it stops at producing a single host binary and reporting its path. This feature adds: reproducible multi-platform compilation (Linux x64 via Docker, macOS arm64 native), versioned persistence of the artifact, a manifest with metadata + integrity hashes, runtime parametrization of the backend(s) under test, a low-coupling cross-repo consumption mechanism, and a freshness guard.

Delivered as a **single PR** (confirmed by the split review: components form a strict 2→1→4→5 dependency chain and are not independently mergeable) with internally sequenced phases.

## Problem Statement / Motivation

The current testeador distribution model is the **inverse** of what we want: it assumes the *consumer repo* compiles the binary in its own CI (via a pub dependency or the MCP). That requires the Dart SDK on the consumer's runner and pays compilation cost on every run.

For the chosen drivers — **consumer without Dart SDK**, **faster pipelines**, and **maximum simplicity for the consumer** — we invert the model: **pre-compile once in the origin repo and distribute the finished binary**. A consumer repo's pipeline should be able to run a flow's integration tests by referencing an Action, passing the relevant tags, and pointing it at its own backend(s).

This maps directly to PRD Journey 1 ("FE publishes the suite → BE consumes it in CI") and FR-12 ("compile to standalone binary, no Dart SDK in CI"), but removes the compile-on-consumer requirement.

## Verified Facts (measured during planning)

- **Binary size ≈ 6.7 MB** for `dart compile exe example/pokebattle_rest/bin/run_tests.dart` (Mach-O arm64, already stripped). The memory bank's "~100 MB" note refers to **Flutter apps** (which bundle the engine), **not** pure-Dart REST suites — that note must be corrected (`docs/memory-bank/03-tech-context.md:21`, `05-progress.md:58`). At ~7 MB, ~150 downloads fit the 1 GB/mo free LFS quota → **caching stays optional/deferred**.
- **Two distinct backends in the canonical example**: `PokeApiClient` → `https://pokeapi.co/api/v2`, the auth/battle clients → `https://api.restful-api.dev`, both as `static const _baseUrl` ([example/pokebattle_rest/lib/data/api_client.dart:11,46,103](../../example/pokebattle_rest/lib/data/api_client.dart#L11)). Actors build a bare `Dio()` with no base URL ([example/pokebattle_rest/test/actors.dart:16-30](../../example/pokebattle_rest/test/actors.dart#L16)). **There is no injection seam today** — Component 3 must open it.
- **`dart compile exe` does not cross-compile**; `dart:stable` is Debian/glibc (runs on `ubuntu-latest`, not Alpine).
- **`raw.githubusercontent.com` serves the LFS pointer; `media.githubusercontent.com/media/...` serves the real bytes.**
- **git-lfs is NOT installed locally** — generation must hard-fail with setup instructions.

## Proposed Solution

Five components, one PR.

### Component 1 — MCP tool `build_suite_runners` (generation)

New tool registered alongside `compile_suite_exe` in [lib/src/mcp/tools/execution_tools.dart](../../lib/src/mcp/tools/execution_tools.dart) (extend `registerExecutionTools`, [execution_tools.dart:14](../../lib/src/mcp/tools/execution_tools.dart#L14)). Reuses `runProcess` ([lib/src/mcp/process_runner.dart](../../lib/src/mcp/process_runner.dart)) and the AST inspector `inspectSuite` ([lib/src/mcp/suite_inspector.dart](../../lib/src/mcp/suite_inspector.dart)). Tool description must match the existing rich style (when to use vs `compile_suite_exe`), per [execution_tools.dart:36-44](../../lib/src/mcp/tools/execution_tools.dart#L36).

Responsibilities, in order:

1. **Preflight (hard-fail, not warn):**
   - `git lfs version` succeeds → else fail: "git-lfs is required; install with `brew install git-lfs && git lfs install`".
   - For a Linux target: `docker info` succeeds → else fail clearly.
   - `.gitattributes` already tracks the output dir as LFS (must exist **before** any binary is written — LFS does not retroactively migrate committed blobs).
2. **Compile per platform:**
   - `linux-x64`: `docker run --platform linux/amd64 --rm -v <root>:/app -w /app dart:stable dart compile exe <suite> -o runners/linux-x64/<name>`.
   - `macos-arm64`: native `dart compile exe <suite> -o runners/macos-arm64/<name>`.
   - No `strip` step — output is already stripped (~7 MB measured).
3. **Per-binary metadata:** sha256, size, dart version.
4. **Derive flow/tag structure from the AST** via `inspectSuite`, preserving the inspector's richness: per-flow `{name, kind, tags}` plus the aggregate `allTags` ([suite_inspector.dart:50-88,117](../../lib/src/mcp/suite_inspector.dart#L50)). Do **not** flatten to a bare tag list (loses tag→flow attribution and weakens the zero-flows guard).
5. **Write `runners/manifest.json` atomically** (write temp + rename; all-or-nothing if any platform fails).
6. **Return** a summary: per-platform path/sha256/size, per-flow structure, source commit, `git add` hint. Supports `execute: false` (return planned commands, mirroring the `{command, working_directory, execute:false}` envelope used by `run_suite_cli`/`compile_suite_exe` — kept for project consistency).

**Output location:** binaries live in **`runners/`** at the repo root, **not** `build/runners/` — `.gitignore` ignores `build/` wholesale ([.gitignore](../../.gitignore)); using `runners/` avoids a fragile negation rule.

```jsonc
// runners/manifest.json (committed PLAIN, not LFS) — no schema_version (YAGNI: add with a real migration path when needed)
{
  "suite_path": "example/pokebattle_rest/bin/run_tests.dart",
  "name": "run_tests",
  "source_commit": "<git rev-parse HEAD at generation>",
  "generated_at": "2026-06-05T12:00:00Z",
  "dart_version": "3.11.0",
  "flows": [
    { "name": "smoke_journey", "kind": "lasting", "tags": ["smoke"] },
    { "name": "regression_suite", "kind": "lasting", "tags": ["regression"] }
  ],
  "all_tags": ["smoke", "regression"],
  "platforms": {
    "linux-x64":  { "path": "runners/linux-x64/run_tests",  "sha256": "…", "size_bytes": 7000000 },
    "macos-arm64":{ "path": "runners/macos-arm64/run_tests","sha256": "…", "size_bytes": 7000000 }
  }
}
```

### Component 2 — Persistence via Git LFS

- New root **`.gitattributes`**:
  ```gitattributes
  runners/linux-x64/** filter=lfs diff=lfs merge=lfs -text
  runners/macos-arm64/** filter=lfs diff=lfs merge=lfs -text
  runners/manifest.json text
  ```
- **`.pubignore`** ([.pubignore](../../.pubignore)) excludes only `*.exe` today; the extensionless binaries + the manifest + root `.gitattributes` must not ship in the pub package. Add `runners/` and verify `dart pub publish --dry-run` stays clean (matches `05-progress.md:18`).
- **One-time setup** documented: `brew install git-lfs && git lfs install`; objects must be `git push`ed for the media URL to resolve them.

### Component 3 — Backend parametrization (open the injection seam)

The chosen model: **keyed `--base-url` flags, one per backend** (consumer just passes the URLs and re-runs — no generic config framework). Because the example has two backends, the flag is keyed.

- Extend the arg parser in [lib/src/testeador.dart](../../lib/src/testeador.dart) (`_buildArgParser`/`_optionsFromArgs`, [testeador.dart:221-274](../../lib/src/testeador.dart#L221)): accept repeatable `--base-url <key>=<url>` (and `--auth-token <key>=<token>` only — no open-ended "credentials as needed").
- Fallback to env `TESTEADOR_BASE_URL_<KEY>` / `TESTEADOR_AUTH_TOKEN_<KEY>`; **CLI flag wins over env**.
- Config flows via a small `TesteadorRuntimeConfig` (keyed map) threaded `Testeador.run` → actor factory → client constructor. It must **not** live in `TesteadorOptions` (filtering-only) — separate object.
- **Open the seam in the example** (allowed by AGENTS.md — this is code, not docs): refactor the two clients in [api_client.dart](../../example/pokebattle_rest/lib/data/api_client.dart) to accept a base URL via constructor (default to the current const, so existing tests stay green), and have the actors inject `config['poke']` / `config['battle']`. This demonstrates the cross-repo pattern end-to-end.

```yaml
# consumer action usage
config-base-urls: |
  poke=https://staging.consumer.com/poke
  battle=https://staging.consumer.com/battle
# action runs: ./run_tests --base-url poke=… --base-url battle=… --include-tags smoke
```

### Component 4 — Reusable composite GitHub Action (consumption)

New **`.github/actions/run-tests/action.yml`** (`runs.using: composite`, `shell: bash` every step), consumed as `uses: <org>/testeador/.github/actions/run-tests@<sha>`.

Inputs: `tags`, `exclude-tags`, `flows`, `exclude-flows`, `config-base-urls` (multiline `key=url`), `auth-tokens` (multiline `key=token`), `github-token` (default `${{ github.token }}`), `fail-on-zero-flows` (default `true`). **No `ref` input** — the consumer pins the binary version by pinning the action ref (`@<sha>`); document this explicitly. **No `actions/cache`** in the MVP (deferred; documented as a future optimization given ~7 MB binaries).

Steps:

1. **Resolve platform** from `${{ runner.os }}`+`${{ runner.arch }}` (`Linux`+`X64`→`linux-x64`, `macOS`+`ARM64`→`macos-arm64`). **No match → fail clearly** with the list of built platforms.
2. **Fetch `runners/manifest.json`** for the expected sha256 + path; optionally validate requested tags against `all_tags` before downloading.
3. **Download via media URL** (never raw): `https://media.githubusercontent.com/media/<org>/<repo>/<action-sha>/runners/<platform>/run_tests` with `Authorization: Bearer <github-token>` (required for private repos).
4. **Integrity gate:** verify **sha256 against the manifest** (primary gate). Sanity-check the response is not the ~130-byte LFS pointer / HTML error (size + first-bytes check) before exec; error message hints "if you got a tiny text file, you fetched raw instead of media".
5. **Make runnable:** `chmod +x`; on macOS `xattr -d com.apple.quarantine`.
6. **Execute** with filters + `--base-url`/`--auth-token`; `set -o pipefail`; **propagate the binary's exact exit code**.
7. **Zero-flows guard via exit code, not stdout parsing:** the binary owns the semantics — `Testeador.run` returns a **distinct exit code (2)** when 0 flows match the filters (today it exits 0, silently "passing" a typo'd tag). The action maps exit 2 → fail when `fail-on-zero-flows: true`. (Replaces the brittle `parseRunSummary` regex coupling.)

### Component 5 — Freshness CI check (source-diff, testable)

A job in [.github/workflows/main.yaml](../../.github/workflows/main.yaml) that fails when suite source changed since `manifest.source_commit` without regenerating runners. Uses git source-diff (binary sha is **not** byte-reproducible across machines, so no binary comparison).

- **Extract the decision into a testable Dart function** (not raw bash): inputs = `source_commit`, changed files, whether `runners/` changed in range; output = pass/fail. Unit-test: source changed + runners not regenerated → fail; source changed + runners regenerated in same range → pass; only docs changed → pass.
- **`$SUITE_PATHS` must include the transitive import set** (a flow imports `test/flows/*.dart` and `lib/data/api_client.dart`); reuse `inspectSuite`'s neighbour resolution ([suite_inspector.dart:468-481](../../lib/src/mcp/suite_inspector.dart#L468)) so a changed imported file isn't missed.

## Technical Considerations

- **Architecture:** new committed-binary distribution mode parallel to the pub-package mode; manifest is the contract metadata.
- **Security:** private-repo downloads require a token; sha256 + pointer/size sanity gate before any `chmod +x`/exec; macOS quarantine cleared; binary embeds no secrets (backend creds injected at run time).
- **Performance:** ~7 MB/binary; media downloads count against LFS bandwidth → caching deferred, not needed at this size.
- **Reproducibility caveat:** binary sha not byte-stable across machines → freshness enforced by source-diff.
- **Scope (YAGNI):** only `linux-x64`+`macos-arm64`; Windows/Linux-arm64/macOS-x64 and non-GitHub CIs out of scope (clear-fail). No `schema_version`, no cache, no open-ended credentials, no auto-resolved ref in the MVP.

## Acceptance Criteria

**Generation (`build_suite_runners`):**
- [ ] Tool registered; description matches the project's rich style (when to use vs `compile_suite_exe`).
- [ ] Hard-fails on missing git-lfs, unavailable Docker (Linux target), or missing `.gitattributes` LFS rule.
- [ ] Compiles `linux-x64` via Docker (`--platform linux/amd64`) and `macos-arm64` natively under `runners/<platform>/<name>`.
- [ ] Writes plain `runners/manifest.json` with source_commit, dart_version, per-platform sha256/size, and per-flow `{name,kind,tags}` + `all_tags` derived via `inspectSuite`.
- [ ] Manifest write is atomic (temp + rename); no partial manifest on platform failure.
- [ ] `execute:false` returns planned commands in the standard envelope.
- [ ] Unit tests: command construction (`execute:false`), manifest serialization round-trip, preflight failures (mocked `runProcess`).

**Persistence:**
- [ ] Root `.gitattributes` tracks `runners/<platform>/**` as LFS, keeps `manifest.json` plain.
- [ ] `.pubignore` excludes `runners/`; `dart pub publish --dry-run` clean.
- [ ] Runbook AC: prove the LFS round-trip (commit → push → fetch via media URL → sanity check passes) on a throwaway commit before merge.
- [ ] README/AGENTS document the one-time `git lfs install` + push requirement.

**Backend parametrization:**
- [ ] `Testeador.run` accepts repeatable `--base-url key=url` / `--auth-token key=token`, falls back to `TESTEADOR_BASE_URL_<KEY>` / `TESTEADOR_AUTH_TOKEN_<KEY>`; flag > env > default.
- [ ] `TesteadorRuntimeConfig` threaded run → actor factory → client; not inside `TesteadorOptions`.
- [ ] Example `pokebattle_rest` clients accept base URL via constructor (default = current const); actors inject `poke`/`battle`; existing tests stay green.
- [ ] Unit tests: flag/env precedence per key.

**Consumption action:**
- [ ] Composite `action.yml` consumable as `uses: <org>/testeador/.github/actions/run-tests@<sha>`; pinning documented (no `ref` input).
- [ ] Resolves platform; fails clearly on unsupported platform.
- [ ] Downloads via media URL with `Authorization: Bearer`; never raw.
- [ ] Verifies sha256 + pointer/size sanity before exec.
- [ ] `chmod +x`; clears macOS quarantine.
- [ ] Forwards filters + base-urls/tokens; propagates exact exit code.
- [ ] `fail-on-zero-flows` (default true) maps the binary's **exit code 2** to failure.
- [ ] **Automated smoke workflow** in testeador CI runs the action against the `pokebattle_rest` runner (download → verify → run → assert exit code + non-zero flow count). Not "manual".

**Freshness CI:**
- [ ] Decision logic extracted to a unit-tested Dart function; `$SUITE_PATHS` includes the transitive import set.
- [ ] Job fails on stale runners, passes otherwise, requires no Dart/Docker in CI.

**Project conventions:**
- [ ] Memory bank updated in the same PR: `04-active-context.md` (and `05-progress.md` on completion), **including correcting the binary-size note** (~7 MB for Dart REST suites; ~100 MB applies to Flutter apps).
- [ ] `dart analyze` clean; `very_good test` green.

## Success Metrics

- A consumer repo runs a flow's tests via the Action with zero Dart SDK and zero compilation, pointing at its own backend(s).
- A corrupted/pointer download is rejected before execution.
- A typo'd tag (0 flows) fails the consumer build instead of passing silently.
- A stale binary is caught by CI, not by a consumer.

## Dependencies & Risks

- **git-lfs not installed locally** → blocks generation (preflight hard-fails; documented).
- **macOS Gatekeeper** → mitigated by clearing quarantine; unsigned binaries may still warn outside CI.
- **glibc skew**: target modern glibc (ubuntu-latest); document minimum.
- **Version pinning**: binary fetched at the action's pinned `@<sha>` ref — consumer must pin a sha, not a mutable tag.
- **Example refactor risk**: opening the injection seam touches `example/` clients + actors; defaulting constructors to the current const keeps existing tests green.
- **LFS bandwidth**: low risk at ~7 MB; caching deferred.

## References & Research

- Primitive to reuse: [`compile_suite_exe`](../../lib/src/mcp/tools/execution_tools.dart#L307); registration/helpers [tools.dart:27](../../lib/src/mcp/tools/tools.dart#L27).
- Process runner: [process_runner.dart](../../lib/src/mcp/process_runner.dart); AST inspector: [suite_inspector.dart:50-88,117,468-481](../../lib/src/mcp/suite_inspector.dart#L50).
- Backend-config reality: [api_client.dart:11,46,103](../../example/pokebattle_rest/lib/data/api_client.dart#L11), [actors.dart:16-30](../../example/pokebattle_rest/test/actors.dart#L16).
- Run/exit + summary line: [testeador.dart:183-185,221-274](../../lib/src/testeador.dart#L183), [curl_parser.dart:74-82](../../lib/src/mcp/curl_parser.dart#L74).
- Size note to correct: [05-progress.md:58](../../docs/memory-bank/05-progress.md#L58), [03-tech-context.md:21](../../docs/memory-bank/03-tech-context.md#L21). Memory-bank update rule: [AGENTS.md:41](../../AGENTS.md#L41).
- Ignore rules: [.gitignore](../../.gitignore) (`build/` ignored), [.pubignore](../../.pubignore) (`*.exe` only). CI: [.github/workflows/main.yaml](../../.github/workflows/main.yaml).
- Git LFS over HTTP (media vs raw): <https://github.com/git-lfs/git-lfs/blob/main/docs/spec.md>
- Composite actions: <https://docs.github.com/en/actions/sharing-automations/creating-actions/creating-a-composite-action>
- Dart Docker image (Debian/glibc): <https://hub.docker.com/_/dart>
- Dart AOT stripped-by-default: <https://dart.dev/tools/dart-compile>
```
