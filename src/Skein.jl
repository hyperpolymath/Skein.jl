# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

"""
    Skein.jl — A knot-theoretic database for Julia

Skein provides storage, indexing, and querying of knot and link data.
Built to work standalone with raw Gauss codes, or as a persistence layer
on top of KnotTheory.jl when that package is loaded.

# Quick start

```julia
using Skein

db = SkeinDB("my_knots.db")

# Store knots by Gauss code
store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))
store!(db, "figure-eight", GaussCode([1, -2, 3, -4, 2, -1, 4, -3]))

# Query by invariant
results = query(db, crossing_number = 3)

# Retrieve
k = fetch_knot(db, "trefoil")

close(db)
```

When KnotTheory.jl is loaded, additional methods become available for
direct storage and retrieval of PlanarDiagram types and richer invariants.
"""
module Skein

using SQLite
using DBInterface
using Dates
using SHA
using UUIDs

# Core types
export GaussCode, KnotRecord, SkeinDB

# Database operations
export store!, query, fetch_knot, list_knots
export update_metadata!, bulk_import!
export import_csv!, export_csv, export_json, dt_to_gauss

# Database lifecycle
export close, isopen

# Invariant computation (standalone, without KnotTheory.jl)
export crossing_number, writhe, gauss_hash

# Equivalence checking
export is_equivalent, is_isotopic, is_amphichiral, mirror, simplify_r1, simplify_r2, simplify
export canonical_gauss
export find_equivalents, find_isotopic

# Polynomial invariants
export LaurentPoly, bracket_polynomial, jones_from_bracket, jones_polynomial_str
export seifert_circles, genus
export serialise_laurent, deserialise_laurent

# Composable query predicates
export QueryPredicate, crossing, writhe_eq, genus_eq, meta_eq, name_like

include("types.jl")
include("polynomials.jl")
include("invariants.jl")
include("storage.jl")
include("query.jl")
include("import_export.jl")

end # module Skein
