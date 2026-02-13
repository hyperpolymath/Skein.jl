# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

"""
Polynomial invariant computation from Gauss codes.

Provides standalone computation of the Kauffman bracket polynomial
and Jones polynomial without requiring KnotTheory.jl.
"""

# -- Laurent polynomial arithmetic --
# Represented as Dict{Int,Int}: exponent => coefficient

const LaurentPoly = Dict{Int,Int}

function lpoly_add(a::LaurentPoly, b::LaurentPoly)::LaurentPoly
    result = copy(a)
    for (e, c) in b
        result[e] = get(result, e, 0) + c
    end
    filter!(p -> p.second != 0, result)
    result
end

function lpoly_mul(a::LaurentPoly, b::LaurentPoly)::LaurentPoly
    result = LaurentPoly()
    for (ea, ca) in a, (eb, cb) in b
        result[ea + eb] = get(result, ea + eb, 0) + ca * cb
    end
    filter!(p -> p.second != 0, result)
    result
end

function lpoly_pow(p::LaurentPoly, n::Int)::LaurentPoly
    n == 0 && return LaurentPoly(0 => 1)
    result = LaurentPoly(0 => 1)
    for _ in 1:n
        result = lpoly_mul(result, p)
    end
    result
end

function lpoly_negate(a::LaurentPoly)::LaurentPoly
    LaurentPoly(e => -c for (e, c) in a)
end

"""
    serialise_laurent(p::LaurentPoly) -> String

Serialise a Laurent polynomial as "exp:coeff,exp:coeff,..." sorted by exponent.
"""
function serialise_laurent(p::LaurentPoly)::String
    isempty(p) && return "0:0"
    pairs = sort(collect(p), by = first)
    join(["$(e):$(c)" for (e, c) in pairs], ",")
end

"""
    deserialise_laurent(s::String) -> LaurentPoly

Parse a serialised Laurent polynomial.
"""
function deserialise_laurent(s::String)::LaurentPoly
    result = LaurentPoly()
    for pair in split(s, ",")
        e_str, c_str = split(pair, ":")
        e, c = parse(Int, e_str), parse(Int, c_str)
        c != 0 && (result[e] = c)
    end
    result
end

# -- Union-Find for component counting --

function uf_find!(parent::Vector{Int}, x::Int)::Int
    while parent[x] != x
        parent[x] = parent[parent[x]]
        x = parent[x]
    end
    x
end

function uf_union!(parent::Vector{Int}, rank::Vector{Int}, x::Int, y::Int)
    rx, ry = uf_find!(parent, x), uf_find!(parent, y)
    rx == ry && return
    if rank[rx] < rank[ry]
        parent[rx] = ry
    elseif rank[rx] > rank[ry]
        parent[ry] = rx
    else
        parent[ry] = rx
        rank[rx] += 1
    end
end

# -- Bracket polynomial --

"""
    bracket_polynomial(g::GaussCode) -> LaurentPoly

Compute the Kauffman bracket polynomial ⟨K⟩ in variable A.

Uses the state sum formula: for each of the 2^n states (one resolution
per crossing), compute the number of resulting loops and accumulate
the contribution A^σ * d^(loops-1) where d = -A² - A⁻² and
σ = (A-resolutions) - (B-resolutions).

The bracket is invariant under Reidemeister II and III moves but
not Reidemeister I (it changes by a factor of -A^±3 per kink).

# Performance
Exponential in crossing number (2^n states). Practical for n ≤ 20.
"""
function bracket_polynomial(g::GaussCode)::LaurentPoly
    n = crossing_number(g)
    n == 0 && return LaurentPoly(0 => 1)

    L = length(g.crossings)
    labels = sort(unique(abs.(g.crossings)))

    # Pre-compute crossing positions and signs
    cpos = Vector{Tuple{Int,Int}}(undef, n)
    csign = Vector{Int}(undef, n)
    for (k, c) in enumerate(labels)
        p1, p2 = 0, 0
        for i in 1:L
            if abs(g.crossings[i]) == c
                p1 == 0 ? (p1 = i) : (p2 = i)
            end
        end
        cpos[k] = (p1, p2)
        csign[k] = sign(g.crossings[p1])
    end

    d = LaurentPoly(2 => -1, -2 => -1)  # d = -A² - A⁻²
    result = LaurentPoly()

    for state in 0:(2^n - 1)
        parent = collect(1:L)
        rank = ones(Int, L)
        a_count = 0

        for k in 1:n
            p, q = cpos[k]
            is_a = ((state >> (k - 1)) & 1) == 0

            bp = mod1(p - 1, L)
            bq = mod1(q - 1, L)

            # Convention: positive crossing + A-res = swap, B-res = separate
            #             negative crossing + A-res = separate, B-res = swap
            do_swap = (csign[k] > 0) == is_a

            if do_swap
                uf_union!(parent, rank, bp, q)
                uf_union!(parent, rank, bq, p)
            else
                uf_union!(parent, rank, bp, p)
                uf_union!(parent, rank, bq, q)
            end

            is_a && (a_count += 1)
        end

        # Count connected components
        components = length(Set(uf_find!(parent, i) for i in 1:L))

        # σ = a - b = 2a - n
        sigma = 2 * a_count - n

        # Contribution: A^σ * d^(components-1)
        d_pow = lpoly_pow(d, components - 1)
        contribution = LaurentPoly(e + sigma => c for (e, c) in d_pow)

        result = lpoly_add(result, contribution)
    end

    result
end

"""
    jones_from_bracket(g::GaussCode) -> LaurentPoly

Compute the Jones polynomial V(t) from the Kauffman bracket.

V(t) = (-A³)^(-w) * ⟨K⟩, where w is the writhe, then substitute t = A⁻⁴.

Returns the polynomial in variable t (exponents are in t, not A).
"""
function jones_from_bracket(g::GaussCode)::LaurentPoly
    bracket = bracket_polynomial(g)
    w = writhe(g)

    # Multiply by (-A³)^(-w) = (-1)^(-w) * A^(-3w)
    # (-1)^(-w) = (-1)^w (since (-1)^(-1) = -1)
    sign_factor = iseven(w) ? 1 : -1
    exp_shift = -3 * w

    # Shift bracket by exp_shift and multiply by sign_factor
    normalised = LaurentPoly(e + exp_shift => c * sign_factor for (e, c) in bracket)
    filter!(p -> p.second != 0, normalised)

    # Convert from A to t: t = A⁻⁴, so A = t^(-1/4)
    # A^k = t^(-k/4)
    # For this to give integer exponents, k must be divisible by 4
    jones = LaurentPoly()
    for (a_exp, coeff) in normalised
        if a_exp % 4 != 0
            # Non-integer t exponent — shouldn't happen for valid knots
            # but store in A-variable form as fallback
            return normalised
        end
        t_exp = -div(a_exp, 4)
        jones[t_exp] = get(jones, t_exp, 0) + coeff
    end
    filter!(p -> p.second != 0, jones)

    jones
end

"""
    jones_polynomial_str(g::GaussCode) -> String

Compute the Jones polynomial and return as a serialised string.
Format: "exp:coeff,exp:coeff,..." sorted by exponent.
"""
function jones_polynomial_str(g::GaussCode)::String
    serialise_laurent(jones_from_bracket(g))
end

# -- Seifert circles --

"""
    seifert_circles(g::GaussCode) -> Vector{Vector{Int}}

Compute the Seifert circles from a Gauss code. Returns a vector of
circles, where each circle is a vector of positions (1-indexed) in
the Gauss code that belong to that circle.

The algorithm: at each position i, instead of continuing to i+1,
jump to the partner position of the same crossing + 1.
"""
function seifert_circles(g::GaussCode)::Vector{Vector{Int}}
    L = length(g.crossings)
    L == 0 && return [Int[]]

    # Build partner map: position → other position of same crossing
    partner = Vector{Int}(undef, L)
    pos_map = Dict{Int, Vector{Int}}()
    for i in 1:L
        c = abs(g.crossings[i])
        ps = get!(pos_map, c, Int[])
        push!(ps, i)
    end
    for (_, ps) in pos_map
        partner[ps[1]] = ps[2]
        partner[ps[2]] = ps[1]
    end

    # seifert_next[i] = mod1(partner[i] + 1, L)
    seifert_next = [mod1(partner[i] + 1, L) for i in 1:L]

    # Find cycles
    visited = falses(L)
    circles = Vector{Vector{Int}}()
    for start in 1:L
        visited[start] && continue
        circle = Int[]
        i = start
        while true
            push!(circle, i)
            visited[i] = true
            i = seifert_next[i]
            i == start && break
        end
        push!(circles, circle)
    end

    circles
end

"""
    genus(g::GaussCode) -> Int

Compute the genus of the Seifert surface from the Gauss code.
genus = (crossings - seifert_circles + 1) / 2
"""
function genus(g::GaussCode)::Int
    n = crossing_number(g)
    n == 0 && return 0
    s = length(seifert_circles(g))
    div(n - s + 1, 2)
end
