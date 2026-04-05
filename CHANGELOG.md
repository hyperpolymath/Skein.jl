<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# Changelog — Skein.jl

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `KnotTheoryExt` Julia package extension: opt-in PlanarDiagram + Knot
  storage path via KnotTheory.jl (test-only extra)
- Schema v4: new indexed columns `diagram_format`, `canonical_diagram`,
  `pd_code`, `alexander_polynomial`, `determinant`, `signature`
- `backfill_gauss_canonical!` for legacy record migration
- `to_knot` / `to_planardiagram` API (stubbed — loaded via extension)
- `INTEGRATION.adoc` documenting layer boundaries
- PROOF-NEEDS.md enumerating schema + storage obligations
- CRG v2 READINESS.md (grade C)

### Changed
- `KnotRecord` struct: added 6 new fields for PD-first storage
  (positional constructor breaking change)
- `store!` refactored via `_store_precomputed!` helper; Gauss-path preserved

## [0.3.1]

### Added
- CRG v2 READINESS.md
- Deploy dogfood-gate, CRG tests and benchmarks
- EXPLAINME.adoc, TEST-NEEDS.md

### Changed
- Migrated SCM files to A2ML format in `.machine_readable/6a2/`

## [0.3.0]

### Added
- Schema v3 with Jones polynomial + Seifert circle indexing
- `query` with invariant filters
- `bulk_import!`, `import_csv!`, `export_csv`, `export_json`

## [0.2.0]

### Added
- Gauss code canonicalisation
- Metadata key-value storage

## [0.1.0]

### Added
- Initial SQLite schema for knot storage
- `SkeinDB`, `KnotRecord`, `GaussCode` types
- `store!`, `fetch_knot`, `list_knots`
