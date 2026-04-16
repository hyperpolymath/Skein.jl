# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
Hardcoded prime knot table through 7 crossings.

Provides instant lookup of prime knot data (Gauss codes, DT notation,
and computed invariants) without requiring a database. Data is computed
once at module load time from the standard Rolfsen table.

# Usage
```julia
using Skein

# Look up a single knot
k = prime_knot("3_1")
k.name              # "3_1"
k.gauss_code        # GaussCode([1, -3, 2, -1, 3, -2])
k.jones_polynomial  # serialised Jones polynomial
k.genus             # 1

# List all prime knots through 7 crossings
all = prime_knots()

# Filter by crossing number
sevens = prime_knots(7)
```
"""

# Raw DT data for prime knots through 7 crossings (Rolfsen table)
const _KNOT_TABLE_DT_DATA = [
    # (name, DT_notation, metadata)

    # -- 0 crossings --
    ("0_1", Int[],
     Dict("type" => "trivial", "alternating" => "true")),

    # -- 3 crossings --
    ("3_1", [4, 6, 2],
     Dict("type" => "torus", "alternating" => "true",
          "family" => "(2,3)-torus", "alias" => "trefoil")),

    # -- 4 crossings --
    ("4_1", [4, 6, 8, 2],
     Dict("type" => "twist", "alternating" => "true",
          "alias" => "figure-eight")),

    # -- 5 crossings --
    ("5_1", [6, 8, 10, 2, 4],
     Dict("type" => "torus", "alternating" => "true",
          "family" => "(2,5)-torus")),
    ("5_2", [4, 8, 10, 2, 6],
     Dict("type" => "twist", "alternating" => "true")),

    # -- 6 crossings --
    ("6_1", [4, 8, 12, 2, 10, 6],
     Dict("type" => "twist", "alternating" => "true",
          "alias" => "stevedore")),
    ("6_2", [4, 8, 10, 12, 2, 6],
     Dict("type" => "alternating", "alternating" => "true")),
    ("6_3", [4, 8, 10, 2, 12, 6],
     Dict("type" => "alternating", "alternating" => "true")),

    # -- 7 crossings --
    ("7_1", [8, 10, 12, 14, 2, 4, 6],
     Dict("type" => "torus", "alternating" => "true",
          "family" => "(2,7)-torus")),
    ("7_2", [4, 10, 14, 12, 2, 8, 6],
     Dict("type" => "alternating", "alternating" => "true")),
    ("7_3", [4, 10, 12, 14, 2, 6, 8],
     Dict("type" => "alternating", "alternating" => "true")),
    ("7_4", [4, 8, 12, 2, 14, 6, 10],
     Dict("type" => "alternating", "alternating" => "true")),
    ("7_5", [6, 8, 12, 14, 4, 2, 10],
     Dict("type" => "alternating", "alternating" => "true")),
    ("7_6", [4, 8, 14, 2, 12, 6, 10],
     Dict("type" => "alternating", "alternating" => "true")),
    ("7_7", [4, 8, 12, 14, 2, 10, 6],
     Dict("type" => "alternating", "alternating" => "true")),
]

# Lazily initialised knot table
const _KNOT_TABLE = Ref{Union{Nothing, Dict{String, NamedTuple}}}(nothing)

function _ensure_knot_table()
    _KNOT_TABLE[] !== nothing && return _KNOT_TABLE[]
    _KNOT_TABLE[] = _build_knot_table()
    return _KNOT_TABLE[]
end

function _build_knot_table()
    table = Dict{String, NamedTuple}()

    for (name, dt, meta) in _KNOT_TABLE_DT_DATA
        gc = dt_to_gauss(dt)
        cn = crossing_number(gc)
        w = writhe(gc)
        sc = seifert_circles(gc)
        g = genus(gc)
        jones = jones_polynomial_str(gc)

        table[name] = (
            name = name,
            gauss_code = gc,
            dt_notation = dt,
            crossing_number = cn,
            writhe = w,
            genus = g,
            seifert_circle_count = length(sc),
            jones_polynomial = jones,
            metadata = meta,
        )
    end

    table
end

"""
    prime_knot(name::String) -> NamedTuple

Look up a prime knot by its Rolfsen name (e.g. "3_1", "7_4").

Returns a NamedTuple with fields: `name`, `gauss_code`, `dt_notation`,
`crossing_number`, `writhe`, `genus`, `seifert_circle_count`,
`jones_polynomial`, `metadata`.

Throws `KeyError` if the name is not in the table (0-7 crossings).

# Example
```julia
k = prime_knot("3_1")
k.genus              # 1
k.crossing_number    # 3
k.jones_polynomial   # serialised Jones polynomial
```
"""
function prime_knot(name::String)
    table = _ensure_knot_table()
    haskey(table, name) || throw(KeyError(name))
    table[name]
end

"""
    prime_knots() -> Vector{NamedTuple}

Return all prime knots in the hardcoded table (through 7 crossings),
sorted by crossing number then index.

# Example
```julia
all = prime_knots()
length(all)  # 15 (0_1 through 7_7)
```
"""
function prime_knots()
    table = _ensure_knot_table()
    entries = collect(values(table))
    sort!(entries, by = e -> (e.crossing_number, e.name))
    entries
end

"""
    prime_knots(n::Int) -> Vector{NamedTuple}

Return all prime knots with exactly `n` crossings.

# Example
```julia
sevens = prime_knots(7)
length(sevens)  # 7
```
"""
function prime_knots(n::Int)
    table = _ensure_knot_table()
    entries = [e for e in values(table) if e.crossing_number == n]
    sort!(entries, by = e -> e.name)
    entries
end
