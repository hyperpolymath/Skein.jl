# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
Core types for Skein.jl

GaussCode is the fundamental representation — a signed integer sequence
where |i| identifies a crossing and sign(i) indicates over/under.
"""

"""
    GaussCode(crossings::Vector{Int})

A knot represented as a Gauss code: a sequence of signed integers
where each crossing appears exactly twice (once positive, once negative).

# Example
```julia
trefoil = GaussCode([1, -2, 3, -1, 2, -3])
```
"""
struct GaussCode
    crossings::Vector{Int}

    function GaussCode(crossings::Vector{Int})
        validate_gauss_code(crossings) || @warn "Gauss code may be malformed"
        new(crossings)
    end
end

Base.length(g::GaussCode) = length(g.crossings)
Base.:(==)(a::GaussCode, b::GaussCode) = a.crossings == b.crossings
Base.show(io::IO, g::GaussCode) = print(io, "GaussCode(", g.crossings, ")")

"""
Validate that a Gauss code is well-formed:
- Each crossing index appears exactly twice
- Each crossing appears once with positive sign and once with negative sign
- No zero entries
"""
function validate_gauss_code(crossings::Vector{Int})
    isempty(crossings) && return true  # unknot

    # No zeros allowed
    any(c -> c == 0, crossings) && return false

    # Each crossing must appear exactly twice
    counts = Dict{Int, Int}()
    for c in crossings
        idx = abs(c)
        counts[idx] = get(counts, idx, 0) + 1
    end
    all(v -> v == 2, values(counts)) || return false

    # Each crossing must appear once positive and once negative
    signs = Dict{Int, Set{Int}}()
    for c in crossings
        idx = abs(c)
        s = get!(signs, idx, Set{Int}())
        push!(s, sign(c))
    end
    all(v -> length(v) == 2 && 1 in v && -1 in v, values(signs))
end

"""
    KnotRecord

A stored knot with computed invariants and metadata.
Returned by query and fetch operations.
"""
struct KnotRecord
    id::String
    name::String
    gauss_code::GaussCode
    diagram_format::String
    canonical_diagram::Union{String, Nothing}
    pd_code::Union{String, Nothing}
    crossing_number::Int
    writhe::Int
    gauss_hash::String
    alexander_polynomial::Union{String, Nothing}
    jones_polynomial::Union{String, Nothing}
    determinant::Union{Int, Nothing}
    signature::Union{Int, Nothing}
    genus::Union{Int, Nothing}
    seifert_circle_count::Union{Int, Nothing}
    metadata::Dict{String, String}
    created_at::DateTime
    updated_at::DateTime
end

function Base.show(io::IO, k::KnotRecord)
    print(io, "KnotRecord(\"", k.name, "\", crossings=", k.crossing_number,
          ", genus=", something(k.genus, "?"), ")")
end

"""
    to_planardiagram(record::KnotRecord)

Convert a stored record back into `KnotTheory.PlanarDiagram`.
Requires KnotTheory.jl to be loaded, which provides the extension method.
"""
function to_planardiagram(::Any)
    error("to_planardiagram requires KnotTheory.jl (load KnotTheory before calling)")
end

"""
    to_knot(record::KnotRecord)

Convert a stored record back into `KnotTheory.Knot`.
Requires KnotTheory.jl to be loaded, which provides the extension method.
"""
function to_knot(::Any)
    error("to_knot requires KnotTheory.jl (load KnotTheory before calling)")
end
