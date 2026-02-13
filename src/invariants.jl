# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

"""
Standalone invariant computations from Gauss codes.

These are intentionally basic — crossing number, writhe, and a content
hash for deduplication. When KnotTheory.jl is loaded, the extension
module adds richer invariants (Jones polynomial, etc.) and delegates
to its verified implementations.
"""

"""
    crossing_number(g::GaussCode) -> Int

The number of distinct crossings in the Gauss code.
Note: this is the *diagram* crossing number, not the minimal crossing
number (which requires Reidemeister simplification).
"""
function crossing_number(g::GaussCode)::Int
    isempty(g.crossings) && return 0
    length(unique(abs.(g.crossings)))
end

"""
    writhe(g::GaussCode) -> Int

The writhe (total signed crossing count) of the knot diagram.
For each crossing, the sign is determined by the order of
positive/negative appearance in the Gauss code.

Writhe is *not* a knot invariant (it depends on the diagram),
but it's useful for indexing and as a component of other invariants.
"""
function writhe(g::GaussCode)::Int
    isempty(g.crossings) && return 0

    # Track first appearance sign for each crossing
    first_sign = Dict{Int, Int}()
    w = 0

    for c in g.crossings
        idx = abs(c)
        s = sign(c)

        if !haskey(first_sign, idx)
            first_sign[idx] = s
        else
            # The crossing sign is determined by whether the first
            # encounter was positive (overcrossing) or negative
            w += first_sign[idx]
        end
    end

    w
end

"""
    gauss_hash(g::GaussCode) -> String

A SHA-256 hash of the normalised Gauss code, used for deduplication.
This identifies identical *diagrams*, not topologically equivalent knots.
"""
function gauss_hash(g::GaussCode)::String
    bytes2hex(sha256(string(g.crossings)))
end

"""
    normalise_gauss(g::GaussCode) -> GaussCode

Relabel crossings to use consecutive integers starting from 1,
preserving the cyclic order. Useful for canonical comparison.
"""
function normalise_gauss(g::GaussCode)::GaussCode
    isempty(g.crossings) && return g

    mapping = Dict{Int, Int}()
    next_label = 1

    normalised = similar(g.crossings)
    for (i, c) in enumerate(g.crossings)
        idx = abs(c)
        if !haskey(mapping, idx)
            mapping[idx] = next_label
            next_label += 1
        end
        normalised[i] = sign(c) * mapping[idx]
    end

    GaussCode(normalised)
end
