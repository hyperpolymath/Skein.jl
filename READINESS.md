<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# Component Readiness — Skein.jl

**Current Grade:** C
**Assessed:** 2026-04-05
**Standard:** [CRG v2.0 STRICT](../standards/component-readiness-grades/)

## Grade rationale (evidence for C)

Works reliably on own project + annotated.

### Evidence

- **Tests:** 844 passing
- **Annotation:** 128 docstrings across `src/`, EXPLAINME.adoc, TEST-NEEDS.md, INTEGRATION.adoc (explicit SoC boundary doc), 4 READMEs
- **RSR compliance:** 0-AI-MANIFEST.a2ml, `.machine_readable/6a2/`, 14+ workflows, SECURITY/CONTRIBUTING/CODE_OF_CONDUCT
- **Julia package extension:** `KnotTheoryExt` — opt-in PD-first storage via proper Julia ecosystem pattern (KnotTheory as test-extra, not runtime dep)
- **Dogfooding:** Consumed by KRLAdapter.jl; integration roundtrips green
- **Schema maturity:** v4 schema with 9 indexed invariant columns + migration path from v3
- **CI:** Clean; panic-attack assail 0 findings

## Gaps preventing higher grades

### Blocks B (6+ diverse external targets)
- No JuliaHub registration yet.
- No external users outside hyperpolymath ecosystem have exercised the storage layer.
- No external bug reports.
- PROOF-NEEDS.md not yet written (storage schemas have obligations that would
  benefit from formal statement).

### Blocks A
- Requires B first.

## What to do for B

1. Register on JuliaHub.
2. Find 6+ diverse external targets — knot researchers with existing knot
   datasets who would benefit from indexed invariant storage.
3. Ship their feedback as fixes; track the 6 targets here.
4. Write PROOF-NEEDS.md for schema migrations and query-result contracts.

## Review cycle

Reassess per release. Next review: on first minor version bump or any test/annotation regression.
