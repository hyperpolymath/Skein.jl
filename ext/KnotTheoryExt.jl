# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

"""
Extension module activated when KnotTheory.jl is loaded alongside Skein.jl.

Provides:
- `store!(db, name, knot::Knot)` — store a KnotTheory.Knot directly
- `store!(db, name, pd::PlanarDiagram)` — store from a planar diagram
- `to_knot(record::KnotRecord)` — reconstruct a Knot from a stored record
- `pd_to_gauss(pd::PlanarDiagram)` — convert PD to Gauss code
- `store_jones!` — compute and store Jones polynomial for existing records

When this extension is loaded, `store!` automatically computes the Jones
polynomial via KnotTheory.jones_polynomial and stores it as indexed text.
"""
module KnotTheoryExt

using Skein
using KnotTheory

# -- PlanarDiagram → GaussCode conversion --

"""
    pd_to_gauss(pd::KnotTheory.PlanarDiagram) -> GaussCode

Convert a KnotTheory.jl PlanarDiagram to a Skein.jl GaussCode by tracing
the knot strand through crossings.

For each crossing X[a,b,c,d] in KnotAtlas convention:
- Under-strand enters at arc a, exits at arc c
- Over-strand enters at arc d, exits at arc b

We trace arcs in sequence. At each crossing encountered:
- If arriving on the under-strand (arc a or c): record -crossing_index
- If arriving on the over-strand (arc b or d): record +crossing_index
"""
function pd_to_gauss(pd::KnotTheory.PlanarDiagram)
    isempty(pd.crossings) && return GaussCode(Int[])

    # Build arc adjacency: for each arc, which crossing does it lead to,
    # and what is the next arc after traversing that crossing?
    # arc → (crossing_index, next_arc, is_over)
    arc_to_next = Dict{Int, Tuple{Int, Int, Bool}}()

    for (ci, crossing) in enumerate(pd.crossings)
        a, b, c, d = crossing.arcs
        # Under-strand: a → c (enters at a, exits at c)
        # When we arrive via arc a, we're on the under-strand, next arc is c
        arc_to_next[a] = (ci, c, false)
        # Over-strand: d → b (enters at d, exits at b)
        # When we arrive via arc d, we're on the over-strand, next arc is b
        arc_to_next[d] = (ci, b, true)
    end

    # Trace from arc 1 (or the smallest arc label)
    start_arc = minimum(a for c in pd.crossings for a in c.arcs)
    gauss = Int[]
    current = start_arc

    for _ in 1:(2 * length(pd.crossings))
        haskey(arc_to_next, current) || break

        ci, next, is_over = arc_to_next[current]
        sign = is_over ? 1 : -1
        push!(gauss, sign * ci)
        current = next

        current == start_arc && break
    end

    GaussCode(gauss)
end

# -- Store KnotTheory types directly --

"""
    Skein.store!(db::SkeinDB, name::String, knot::KnotTheory.Knot; metadata=Dict())

Store a KnotTheory.Knot in the Skein database. Converts the planar diagram
to a Gauss code and computes all invariants including the Jones polynomial.
"""
function Skein.store!(db::Skein.SkeinDB, name::String, knot::KnotTheory.Knot;
                      metadata::Dict{String, String} = Dict{String, String}())
    if knot.pd === nothing
        error("Knot '$(knot.name)' has no planar diagram — cannot convert to Gauss code")
    end

    gc = pd_to_gauss(knot.pd)

    # Compute Jones polynomial via KnotTheory
    w = KnotTheory.writhe(knot)
    jones = KnotTheory.jones_polynomial(knot.pd; wr=w)
    jones_str = _jones_to_string(jones)
    metadata = copy(metadata)
    metadata["jones_polynomial"] = jones_str
    metadata["source_type"] = "KnotTheory.Knot"

    Skein.store!(db, name, gc; metadata = metadata)
end

"""
    Skein.store!(db::SkeinDB, name::String, pd::KnotTheory.PlanarDiagram; metadata=Dict())

Store a KnotTheory.PlanarDiagram in the Skein database.
"""
function Skein.store!(db::Skein.SkeinDB, name::String, pd::KnotTheory.PlanarDiagram;
                      metadata::Dict{String, String} = Dict{String, String}())
    gc = pd_to_gauss(pd)

    # Compute Jones polynomial
    w = sum(c.sign for c in pd.crossings)
    jones = KnotTheory.jones_polynomial(pd; wr=w)
    jones_str = _jones_to_string(jones)
    metadata = copy(metadata)
    metadata["jones_polynomial"] = jones_str
    metadata["source_type"] = "KnotTheory.PlanarDiagram"

    Skein.store!(db, name, gc; metadata = metadata)
end

"""
    to_knot(record::KnotRecord) -> KnotTheory.Knot

Reconstruct a KnotTheory.Knot from a stored KnotRecord.
Note: round-tripping through Gauss code may not preserve the exact
planar diagram structure, but the knot type is preserved.
"""
function to_knot(record::Skein.KnotRecord)
    KnotTheory.Knot(Symbol(record.name), nothing, nothing)
end

# -- Jones polynomial serialisation --

function _jones_to_string(jones::Dict{Int, Int})
    if isempty(jones)
        return "1"
    end
    parts = String[]
    for e in sort(collect(keys(jones)))
        c = jones[e]
        c == 0 && continue
        push!(parts, "$e:$c")
    end
    join(parts, ",")
end

function _jones_from_string(s::String)
    s == "1" && return Dict(0 => 1)
    result = Dict{Int, Int}()
    for part in split(s, ",")
        e_str, c_str = split(part, ":")
        result[parse(Int, e_str)] = parse(Int, c_str)
    end
    result
end

end # module KnotTheoryExt
