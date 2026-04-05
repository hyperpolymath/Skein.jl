<!-- SPDX-License-Identifier: MPL-2.0 -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk> -->

# PROOF-NEEDS — Skein.jl

Schema and storage obligations for the knot persistence layer. These are
claims the library makes that would benefit from formal proof or, at minimum,
strong property-test evidence.

## Currently verified (by unit + E2E tests, 844 assertions)

| Claim | Evidence |
|---|---|
| Gauss code roundtrip: `deserialise_gauss(serialise_gauss(g)) == g` | `test/runtests.jl` |
| Schema migration v2→v3→v4 preserves stored records | `test/runtests.jl` |
| `store!` then `fetch_knot` returns equivalent `KnotRecord` | `test/runtests.jl` |
| `query` with invariant filter returns records whose invariants match | `test/runtests.jl` |
| KnotTheoryExt: `PlanarDiagram` storage caches invariants correctly | `test/knot_theory_ext_test.jl` |

## Would benefit from formal proof

### S1. Schema migration preserves all data
Statement: For every pair of schema versions (vN → vN+1), the migration
function leaves the set of retrievable `KnotRecord`s identical in terms of
their gauss_code, crossing_number, writhe, and metadata.

Current status: tested by example; not proved for arbitrary databases.
Important because migrations run against user data.

### S2. Query result correctness
Statement: `query(db; filter)` returns exactly the set of records R where
predicate(filter, R) holds, with respect to the schema's typed indexes.

Current status: tested for each filter type individually; no exhaustive
composition-of-filters proof.

### S3. Canonical Gauss code correctness
Statement: For any two Gauss codes g₁, g₂ representing the same oriented
knot diagram up to rotation/reflection, `canonical_gauss(g₁) == canonical_gauss(g₂)`.

Current status: tested on small examples. Would benefit from stronger
property-based testing across generated equivalent diagrams.

### S4. Invariant cache consistency
Statement: If a record's `canonical_diagram` and `jones_polynomial` are both
populated, they are consistent — i.e. computing Jones from the canonical
diagram would yield the stored polynomial.

Current status: not enforced by the schema; relied on by convention. A
consistency check would catch drift between cache and source.

## Schema obligations (contract-level)

- `UNIQUE(name)` constraint in `knots` table: enforced by SQLite.
- `diagram_format ∈ {"gauss", "pd"}`: convention, not enforced by schema.
  Could be added as a CHECK constraint.
- Foreign key integrity on `knot_metadata.knot_id`: relies on SQLite foreign
  key enforcement (enabled via PRAGMA?).

## How to propose a new obligation

1. State the claim precisely here.
2. Add a property-based test OR a formal proof.
3. Move discharged items to the "Currently verified" table with evidence.
