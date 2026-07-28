---
title: "feat: manifest endpoint-coverage field + EndpointId normalizer"
type: feat
date: 2026-06-05
part: 1 of 5
---

## feat: manifest endpoint-coverage field + EndpointId normalizer (PR-1) - Standard

> Part 1 of the split from [2026-06-05-feat-contract-discovery-from-app-traffic-plan.md](2026-06-05-feat-contract-discovery-from-app-traffic-plan.md). Foundation: the shared identity function and the coverage baseline both later phases diff against. Touches no capture code.

## Dependencies

- **None.** This is the foundation PR; everything else depends on it.
- Subsystem rule: the manifest change lives in `codegen/`; `capture/` will later depend on `codegen/`, **never the reverse**. `EndpointId` is the one type shared by both, placed in `lib/src/capture/endpoint_id.dart` but with no dependency on capture I/O.

## Overview

Add the `EndpointId` value type + path-templating function (the single source of endpoint identity used on both sides of the future gap diff), and extend the codegen manifest so each captured test can record which endpoints it covers. No traffic capture, no generation — pure data + pure logic, 100% unit-testable with fixtures.

## Problem

The gap diff (exercised − covered) needs (1) a deterministic endpoint identity shared by both sides, and (2) a place to record coverage. Today the manifest (`lib/src/codegen/aggregator.dart` — `FileManifest`/`DiscoveredTest`) carries only `{name, groupChain, tags}`. Without both, the headline feature cannot compute a gap.

## Technical Approach

### `EndpointId` (new — `lib/src/capture/endpoint_id.dart`)

```dart
/// Identity = (method, templatedPath, service). The SAME normalizer is used
/// for exercised and covered sets, or the diff is meaningless.
class EndpointId {
  const EndpointId({required this.method, required this.templatedPath, required this.service});
  final String method;        // upper-cased, e.g. GET
  final String templatedPath; // /users/{id}
  final String service;       // host or logical service name
}

/// Numeric, UUID, and long hex path segments -> `{id}`.
/// Query params and status code are ATTRIBUTES of a captured contract, NOT identity.
EndpointId normalizeEndpoint({required String method, required Uri url, String? service});
```

### Manifest schema change (`lib/src/codegen/aggregator.dart`)

Add a **nullable** `coveredEndpoints` to each test entry:

```jsonc
{
  "name": "registers a new trainer",
  "groupChain": ["players"],
  "tags": ["smoke"],
  "coveredEndpoints": [                       // NEW — nullable
    { "method": "POST", "path": "/players", "service": "restful-api.dev" }
  ]
}
```

**Nullability is load-bearing (review finding #4):**
- `null` / absent ⇒ test is **un-annotated** → drives a precise per-test cold-start warning.
- `[]` ⇒ test is annotated and genuinely covers **no** endpoints.
- These must be distinguishable; do not collapse absent into `[]`.

### Tasks

- [ ] `lib/src/capture/endpoint_id.dart`: `EndpointId` + `normalizeEndpoint` (numeric/UUID/hex → `{id}`; method upper-cased; query/status excluded from identity).
- [ ] `lib/src/codegen/aggregator.dart`: add `List<EndpointId>? coveredEndpoints` to `DiscoveredTest`; update `FileManifest.toJson`/`fromJson` to round-trip it, preserving the `null` vs `[]` distinction.
- [ ] `lib/src/discovery/manifest_reader.dart`: surface `coveredEndpoints`; emit a **per-test** cold-start warning when `null`.
- [ ] No behavior change to existing scan/transform/aggregate flow when the field is absent (back-compat for already-generated manifests).

## Testing (no-mocks story — review finding #1)

These are **pure functions tested with fixed input data (fixtures), not mocks of a system under test** — fully compatible with AGENTS.md "no mocks." `mocktail` is allowed for testeador's own tests if ever needed, never for user flows.

- [ ] `EndpointId`/`normalizeEndpoint`: table-driven over fixtures — `/users/123`, `/users/<uuid>`, `/users/{id}?expand=team`, `/a/1/b/2`, trailing slashes, case. Assert idempotency (`normalize(normalize(x)) == normalize(x)`).
- [ ] Manifest round-trip: `null` vs absent vs `[]` are all distinct after `toJson`→`fromJson`; legacy manifest without the field loads as `null`.

## Acceptance Criteria

- [ ] One shared `EndpointId` identity function exists; numeric/UUID/hex → `{id}`; query/status not part of identity.
- [ ] Manifest round-trips `coveredEndpoints` preserving `null`/`[]` distinction; legacy manifests still parse.
- [ ] `manifest_reader` warns per-test on un-annotated (`null`) coverage.
- [ ] `dart analyze` clean; new pure-logic units at 100% coverage; `very_good test` green.
- [ ] memory-bank `04-active-context.md` updated with the claim line for this PR.

## References

- `lib/src/codegen/aggregator.dart:9-90` (FileManifest/DiscoveredTest schema)
- `lib/src/discovery/manifest_reader.dart:18-78`
- AGENTS.md "no mocks"; `docs/memory-bank/` tech-context (mocktail allowed for testeador's own tests).
