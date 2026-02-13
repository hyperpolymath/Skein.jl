# Skein.jl — Project Instructions

## Overview

Skein.jl is a knot-theoretic database for Julia. It stores knots as Gauss codes,
computes invariants on insert, and provides querying by those invariants.

## Build & Test

```bash
# Run tests (567+ tests, ~15s)
julia --project=. -e 'using Pkg; Pkg.test()'

# Run benchmarks
julia --project=. benchmark/benchmarks.jl

# Resolve dependencies
julia --project=. -e 'using Pkg; Pkg.resolve()'
```

## Architecture

- **src/types.jl** — Core types: `GaussCode`, `KnotRecord`
- **src/polynomials.jl** — Laurent polynomial arithmetic, Kauffman bracket, Jones polynomial
- **src/invariants.jl** — Standalone invariant computation + equivalence checking (R1, R2)
- **src/storage.jl** — SQLite backend, schema v2, CRUD operations
- **src/query.jl** — Keyword queries + composable predicates (`&`, `|`)
- **src/import_export.jl** — CSV/JSON export, KnotInfo import (36 knots through 8 crossings), DT-to-Gauss conversion, bulk import
- **ext/KnotTheoryExt.jl** — Package extension for KnotTheory.jl integration

## Key Patterns

- **SQLite.jl cursors**: Always iterate directly (`for row in result`), never `collect()` then access — SQLite.jl 1.8 finalises cursor data after collect
- **Missing handling**: All `row[:col]` values may be `Missing`; use `ismissing()` checks
- **KnotTheory.jl**: Weakdep only — never add as hard dependency
- **Schema migration**: `_get_schema_version` + `_migrate_v1_to_v2` pattern
- **Base extensions**: `Base.delete!`, `Base.haskey`, `Base.close`, `Base.isopen` — extend, don't re-export

## Critical Invariants

- All files must have `SPDX-License-Identifier: PMPL-1.0-or-later` header
- SCM files in `.machine_readable/` ONLY
- Tests must pass before any commit
- Author: `Jonathan D.A. Jewell <jonathan.jewell@open.ac.uk>`
