<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# Skein.jl — Project Instructions

## Overview

Skein.jl is a knot-theoretic database for Julia. It stores knots as Gauss codes,
computes invariants on insert (Jones polynomial, genus, Seifert circles), and
provides querying by those invariants.

Skein.jl is an independent Julia library for knot storage, indexing and invariant
computation. KnotTheory.jl is a separate mathematical toolkit. QuandleDB uses
these libraries and implements its KRL resolution-language fragment, but does not
define the libraries' purpose. Tangle is a separate Turing-complete language for
knot mathematics. Shared subject matter creates no KRL-to-Tangle compilation
pipeline and transfers no proof guarantee.

## Build & Test

```bash
# Run tests (1089 tests, ~20s; needs sibling path-deps ../AcceleratorGate.jl + ../KnotTheory.jl)
julia --project=. -e 'using Pkg; Pkg.test()'

# Run benchmarks
julia --project=. benchmark/benchmarks.jl

# Resolve dependencies
julia --project=. -e 'using Pkg; Pkg.resolve()'
```

## Architecture

- **src/types.jl** — Core types: `GaussCode`, `KnotRecord` (with genus, seifert_circle_count)
- **src/polynomials.jl** — Laurent polynomial arithmetic, Kauffman bracket, Jones polynomial, Seifert circles, genus
- **src/invariants.jl** — Standalone invariant computation + equivalence checking (R1, R2, Jones comparison)
- **src/storage.jl** — SQLite backend, schema v4 (auto-migrations v1→v4; PD-native fields `diagram_format`/`canonical_diagram`/`pd_code`), CRUD with auto-computed invariants
- **src/query.jl** — Keyword queries + composable predicates (`&`, `|`) including genus
- **src/import_export.jl** — CSV/JSON export, KnotInfo import (36 knots through 8 crossings), DT-to-Gauss conversion, bulk import
- **src/knot_table.jl** — Hardcoded prime-knot table through 7 crossings (`prime_knot`, `prime_knots`)
- **src/backends/abstract.jl** — Abstract storage-backend interface
- **ext/KnotTheoryExt.jl** — Package extension for KnotTheory.jl integration

## Key Patterns

- **SQLite.jl cursors**: Always iterate directly (`for row in result`), never `collect()` then access — SQLite.jl 1.8 finalises cursor data after collect
- **Missing handling**: All `row[:col]` values may be `Missing`; use `ismissing()` checks
- **KnotTheory.jl**: Weakdep only — never add as hard dependency
- **Schema migration**: `_get_schema_version` + `_migrate_vN_to_vM` pattern (v1→v2→v3→v4); a proposed v5 "knot-relation edge layer" was withdrawn (mis-grounded on "KRL = query") — no committed next schema version until specified against Skein’s own storage requirements
- **Base extensions**: `Base.delete!`, `Base.haskey`, `Base.close`, `Base.isopen` — extend, don't re-export
- **Auto-computed invariants**: `store!` auto-computes Jones (≤15 crossings), genus, and Seifert circles
- **Alexander polynomial**: NOT implemented — requires crossing chirality data not in basic Gauss codes

## Critical Invariants

<!-- REUSE-IgnoreStart -->
- All files must have `SPDX-License-Identifier: CC-BY-SA-4.0` header
<!-- REUSE-IgnoreEnd -->
- SCM files in `.machine_readable/` ONLY
- Tests must pass before any commit
- Author: `Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>`
