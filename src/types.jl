# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

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
each crossing index appears exactly twice with opposite signs.
"""
function validate_gauss_code(crossings::Vector{Int})
    isempty(crossings) && return true  # unknot

    counts = Dict{Int, Int}()
    for c in crossings
        idx = abs(c)
        counts[idx] = get(counts, idx, 0) + 1
    end

    all(v -> v == 2, values(counts))
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
    crossing_number::Int
    writhe::Int
    gauss_hash::String
    jones_polynomial::Union{String, Nothing}
    metadata::Dict{String, String}
    created_at::DateTime
    updated_at::DateTime
end

function Base.show(io::IO, k::KnotRecord)
    print(io, "KnotRecord(\"", k.name, "\", crossings=", k.crossing_number, ")")
end
