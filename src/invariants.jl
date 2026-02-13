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

# -- Equivalence checking --

"""
    canonical_gauss(g::GaussCode) -> GaussCode

Compute a canonical form for a Gauss code by trying all cyclic rotations,
normalising each, and returning the lexicographically smallest.
Two Gauss codes that differ only by cyclic rotation and relabelling
will produce the same canonical form.
"""
function canonical_gauss(g::GaussCode)::GaussCode
    isempty(g.crossings) && return g
    n = length(g.crossings)

    best = normalise_gauss(g).crossings

    for shift in 1:(n-1)
        rotated = circshift(g.crossings, -shift)
        normed = normalise_gauss(GaussCode(rotated)).crossings
        if normed < best
            best = normed
        end
    end

    GaussCode(best)
end

"""
    is_equivalent(g1::GaussCode, g2::GaussCode) -> Bool

Check whether two Gauss codes represent the same knot diagram
up to cyclic rotation and crossing relabelling.

This checks *diagram* equivalence, not topological equivalence.
For topological equivalence, use `is_isotopic` which also applies
Reidemeister simplification.
"""
function is_equivalent(g1::GaussCode, g2::GaussCode)::Bool
    crossing_number(g1) != crossing_number(g2) && return false
    canonical_gauss(g1) == canonical_gauss(g2)
end

"""
    mirror(g::GaussCode) -> GaussCode

Return the mirror image of a Gauss code (flip all crossing signs).
"""
function mirror(g::GaussCode)::GaussCode
    GaussCode(-g.crossings)
end

"""
    is_amphichiral(g::GaussCode) -> Bool

Check if a knot diagram is equivalent to its mirror image.
A knot is amphichiral if it is isotopic to its mirror.
This checks diagram-level amphichirality (rotation + relabelling).
"""
function is_amphichiral(g::GaussCode)::Bool
    is_equivalent(g, mirror(g))
end

"""
    simplify_r1(g::GaussCode) -> GaussCode

Remove Reidemeister I moves (kinks/curls) from a Gauss code.
A Reidemeister I move appears as two adjacent entries ±i, ∓i
for some crossing i (a crossing that loops back on itself).
"""
function simplify_r1(g::GaussCode)::GaussCode
    isempty(g.crossings) && return g

    changed = true
    current = copy(g.crossings)

    while changed
        changed = false
        i = 1
        while i < length(current)
            if abs(current[i]) == abs(current[i+1]) && sign(current[i]) != sign(current[i+1])
                deleteat!(current, [i, i+1])
                changed = true
            else
                i += 1
            end
        end

        # Check wrap-around (cyclic adjacency of first and last)
        if length(current) >= 2
            if abs(current[1]) == abs(current[end]) && sign(current[1]) != sign(current[end])
                deleteat!(current, [1, length(current)])
                changed = true
            end
        end
    end

    GaussCode(current)
end

"""
    is_isotopic(g1::GaussCode, g2::GaussCode) -> Bool

Check whether two Gauss codes are topologically equivalent by
simplifying both with Reidemeister I moves and then checking
diagram equivalence (cyclic rotation + relabelling).

This is a heuristic — it catches many common equivalences but
cannot detect all isotopies (full Reidemeister II and III would
require more sophisticated algorithms).
"""
function is_isotopic(g1::GaussCode, g2::GaussCode)::Bool
    s1 = simplify_r1(g1)
    s2 = simplify_r1(g2)
    is_equivalent(s1, s2)
end
