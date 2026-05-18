# SPDX-License-Identifier: MPL-2.0
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

# Raw data for prime knots through 7 crossings (Rolfsen table).
#
# Each entry carries BOTH the Dowker-Thistlethwaite code (kept for the
# `gauss_code` / `dt_notation` fields and for round-tripping through
# `dt_to_gauss`) AND the authoritative Knot Atlas planar-diagram (PD) code.
#
# The Jones polynomial is a *diagram* invariant: its per-state loop count
# depends on the rotation system of the diagram, which a bare Gauss code
# (the route used previously) does NOT encode — so a Gauss-code bracket
# collapses topologically distinct knots (e.g. the figure-eight 4_1 reduces
# to a single monomial). The PD code DOES encode the planar embedding, so
# the Jones polynomial is computed here from the PD code via the planar
# Kauffman state sum (`jones_from_pd`).
#
# The PD codes below are the canonical Knot Atlas (Rolfsen table) planar
# diagrams, transcribed from https://katlas.org/wiki/<name>. Every entry's
# resulting Jones polynomial has been verified term-for-term against the
# published Knot Atlas Jones polynomial — see the test suite.
const _KNOT_TABLE_DT_DATA = [
    # (name, DT_notation, PD_code, metadata)

    # -- 0 crossings --
    ("0_1", Int[], "",
     Dict("type" => "trivial", "alternating" => "true")),

    # -- 3 crossings --
    ("3_1", [4, 6, 2], "X1,4,2,5 X3,6,4,1 X5,2,6,3",
     Dict("type" => "torus", "alternating" => "true",
          "family" => "(2,3)-torus", "alias" => "trefoil")),

    # -- 4 crossings --
    ("4_1", [4, 6, 8, 2], "X4,2,5,1 X8,6,1,5 X6,3,7,4 X2,7,3,8",
     Dict("type" => "twist", "alternating" => "true",
          "alias" => "figure-eight")),

    # -- 5 crossings --
    ("5_1", [6, 8, 10, 2, 4], "X1,6,2,7 X3,8,4,9 X5,10,6,1 X7,2,8,3 X9,4,10,5",
     Dict("type" => "torus", "alternating" => "true",
          "family" => "(2,5)-torus")),
    ("5_2", [4, 8, 10, 2, 6], "X1,4,2,5 X3,8,4,9 X5,10,6,1 X9,6,10,7 X7,2,8,3",
     Dict("type" => "twist", "alternating" => "true")),

    # -- 6 crossings --
    ("6_1", [4, 8, 12, 2, 10, 6],
     "X1,4,2,5 X7,10,8,11 X3,9,4,8 X9,3,10,2 X5,12,6,1 X11,6,12,7",
     Dict("type" => "twist", "alternating" => "true",
          "alias" => "stevedore")),
    ("6_2", [4, 8, 10, 12, 2, 6],
     "X1,4,2,5 X5,10,6,11 X3,9,4,8 X9,3,10,2 X7,12,8,1 X11,6,12,7",
     Dict("type" => "alternating", "alternating" => "true")),
    ("6_3", [4, 8, 10, 2, 12, 6],
     "X4,2,5,1 X8,4,9,3 X12,9,1,10 X10,5,11,6 X6,11,7,12 X2,8,3,7",
     Dict("type" => "alternating", "alternating" => "true")),

    # -- 7 crossings --
    ("7_1", [8, 10, 12, 14, 2, 4, 6],
     "X1,8,2,9 X3,10,4,11 X5,12,6,13 X7,14,8,1 X9,2,10,3 X11,4,12,5 X13,6,14,7",
     Dict("type" => "torus", "alternating" => "true",
          "family" => "(2,7)-torus")),
    ("7_2", [4, 10, 14, 12, 2, 8, 6],
     "X1,4,2,5 X3,10,4,11 X5,14,6,1 X7,12,8,13 X11,8,12,9 X13,6,14,7 X9,2,10,3",
     Dict("type" => "alternating", "alternating" => "true")),
    ("7_3", [4, 10, 12, 14, 2, 6, 8],
     "X6,2,7,1 X10,4,11,3 X14,8,1,7 X8,14,9,13 X12,6,13,5 X2,10,3,9 X4,12,5,11",
     Dict("type" => "alternating", "alternating" => "true")),
    ("7_4", [4, 8, 12, 2, 14, 6, 10],
     "X6,2,7,1 X12,6,13,5 X14,8,1,7 X8,14,9,13 X2,12,3,11 X10,4,11,3 X4,10,5,9",
     Dict("type" => "alternating", "alternating" => "true")),
    ("7_5", [6, 8, 12, 14, 4, 2, 10],
     "X1,4,2,5 X3,10,4,11 X5,12,6,13 X7,14,8,1 X13,6,14,7 X11,8,12,9 X9,2,10,3",
     Dict("type" => "alternating", "alternating" => "true")),
    ("7_6", [4, 8, 14, 2, 12, 6, 10],
     "X1,4,2,5 X3,8,4,9 X5,12,6,13 X9,1,10,14 X13,11,14,10 X11,6,12,7 X7,2,8,3",
     Dict("type" => "alternating", "alternating" => "true")),
    ("7_7", [4, 8, 12, 14, 2, 10, 6],
     "X1,4,2,5 X5,10,6,11 X3,9,4,8 X9,3,10,2 X11,14,12,1 X7,13,8,12 X13,7,14,6",
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

    for (name, dt, pd_str, meta) in _KNOT_TABLE_DT_DATA
        gc = dt_to_gauss(dt)
        cn = crossing_number(gc)
        w = writhe(gc)
        sc = seifert_circles(gc)
        g = genus(gc)

        # The Jones polynomial is computed from the canonical Knot Atlas
        # PLANAR DIAGRAM, not the Gauss code: the Kauffman bracket is a
        # diagram invariant whose loop counts require the planar embedding
        # that a bare Gauss code cannot encode. Each result is verified
        # term-for-term against the published Knot Atlas value in the tests.
        pd = parse_pd(pd_str)
        jones = jones_from_pd_str(pd)

        table[name] = (
            name = name,
            gauss_code = gc,
            dt_notation = dt,
            pd_code = pd_str,
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
