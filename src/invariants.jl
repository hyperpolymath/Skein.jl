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
    simplify_r2(g::GaussCode) -> GaussCode

Remove Reidemeister II moves (bigons) from a Gauss code.
Two crossings i and j form an R2 pair if their four appearances
alternate in the cyclic code (i,j,i,j pattern), both crossings
change sign between appearances, and no other crossing is
interleaved between them (linking condition).
"""
function simplify_r2(g::GaussCode)::GaussCode
    isempty(g.crossings) && return g

    changed = true
    current = copy(g.crossings)

    while changed
        changed = false
        labels = unique(abs.(current))
        n_labels = length(labels)

        for i in 1:n_labels, j in (i+1):n_labels
            ci, cj = labels[i], labels[j]

            pos_ci = findall(x -> abs(x) == ci, current)
            pos_cj = findall(x -> abs(x) == cj, current)
            length(pos_ci) == 2 || continue
            length(pos_cj) == 2 || continue

            if _is_r2_pair(current, ci, cj, pos_ci, pos_cj)
                filter!(x -> abs(x) != ci && abs(x) != cj, current)
                changed = true
                break
            end
        end
    end

    GaussCode(current)
end

function _is_r2_pair(code::Vector{Int}, ci::Int, cj::Int,
                     pos_ci::Vector{Int}, pos_cj::Vector{Int})::Bool
    # Sort all 4 positions
    all_pos = sort([pos_ci..., pos_cj...])

    # Check alternation: crossings must alternate (i,j,i,j or j,i,j,i)
    ids = [abs(code[p]) for p in all_pos]
    (ids[1] == ids[3] && ids[2] == ids[4] && ids[1] != ids[2]) || return false

    # Check opposite signs for each crossing
    sign(code[pos_ci[1]]) != sign(code[pos_ci[2]]) || return false
    sign(code[pos_cj[1]]) != sign(code[pos_cj[2]]) || return false

    # Linking condition: no other crossing has appearances in opposite arcs
    L = length(code)
    arc_contents = [Set{Int}() for _ in 1:4]

    for arc_idx in 1:4
        start = all_pos[arc_idx]
        stop = all_pos[mod1(arc_idx + 1, 4)]
        pos = start
        while true
            pos = mod1(pos + 1, L)
            pos == stop && break
            c = abs(code[pos])
            (c == ci || c == cj) && continue
            push!(arc_contents[arc_idx], c)
        end
    end

    # Opposite arcs (1&3, 2&4) must not share any crossing
    isempty(intersect(arc_contents[1], arc_contents[3])) &&
    isempty(intersect(arc_contents[2], arc_contents[4]))
end

"""
    simplify(g::GaussCode) -> GaussCode

Apply Reidemeister I and II simplifications exhaustively.
Returns the simplified Gauss code.
"""
function simplify(g::GaussCode)::GaussCode
    prev = g
    while true
        s = simplify_r1(prev)
        s = simplify_r2(s)
        s == prev && return s
        prev = s
    end
end

"""
    is_isotopic(g1::GaussCode, g2::GaussCode) -> Bool

Check whether two Gauss codes are topologically equivalent by
simplifying both with Reidemeister I and II moves, then checking
diagram equivalence (cyclic rotation + relabelling).

This catches many common equivalences. Full topological equivalence
detection (Reidemeister III) would require more sophisticated
algorithms or Jones polynomial comparison.
"""
function is_isotopic(g1::GaussCode, g2::GaussCode)::Bool
    s1 = simplify(g1)
    s2 = simplify(g2)

    # Fast path: same canonical form after simplification
    is_equivalent(s1, s2) && return true

    # Stronger check: compare Jones polynomials if crossing numbers match
    if crossing_number(s1) == crossing_number(s2) && crossing_number(s1) <= 15
        j1 = jones_from_bracket(s1)
        j2 = jones_from_bracket(s2)
        # Different Jones polys → definitely not isotopic
        j1 != j2 && return false
        # Same Jones poly → likely isotopic (not proven in general)
        return true
    end

    false
end
