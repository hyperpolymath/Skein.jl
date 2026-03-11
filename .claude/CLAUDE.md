# Skein.jl — Project Instructions

## Overview

Skein.jl is a knot-theoretic database for Julia. It stores knots as Gauss codes,
computes invariants on insert (Jones polynomial, genus, Seifert circles), and
provides querying by those invariants.

## Build & Test

```bash
# Run tests (611+ tests, ~16s)
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
- **src/storage.jl** — SQLite backend, schema v3, CRUD with auto-computed invariants
- **src/query.jl** — Keyword queries + composable predicates (`&`, `|`) including genus
- **src/import_export.jl** — CSV/JSON export, KnotInfo import (36 knots through 8 crossings), DT-to-Gauss conversion, bulk import
- **ext/KnotTheoryExt.jl** — Package extension for KnotTheory.jl integration

## Key Patterns

- **SQLite.jl cursors**: Always iterate directly (`for row in result`), never `collect()` then access — SQLite.jl 1.8 finalises cursor data after collect
- **Missing handling**: All `row[:col]` values may be `Missing`; use `ismissing()` checks
- **KnotTheory.jl**: Weakdep only — never add as hard dependency
- **Schema migration**: `_get_schema_version` + `_migrate_vN_to_vM` pattern (v1→v2→v3)
- **Base extensions**: `Base.delete!`, `Base.haskey`, `Base.close`, `Base.isopen` — extend, don't re-export
- **Auto-computed invariants**: `store!` auto-computes Jones (≤15 crossings), genus, and Seifert circles
- **Alexander polynomial**: NOT implemented — requires crossing chirality data not in basic Gauss codes

## Critical Invariants

- All files must have `SPDX-License-Identifier: PMPL-1.0-or-later` header
- SCM files in `.machine_readable/` ONLY
- Tests must pass before any commit
- Author: `Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>`
