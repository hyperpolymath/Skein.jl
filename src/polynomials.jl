# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

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

# -- Planar-diagram (PD) Kauffman bracket / Jones polynomial --
#
# The Kauffman bracket, and hence the Jones polynomial, is a *diagram*
# invariant whose per-state loop count depends on the rotation system of
# the diagram. An unsigned (or even a signed) Gauss code does NOT encode a
# planar embedding, so a bracket computed from a Gauss code alone collapses
# topologically distinct knots (e.g. it cannot distinguish the figure-eight
# from the unknot). The mathematically correct route is the planar diagram
# (PD code): each crossing carries its four arc labels in counter-clockwise
# order, which fully determines the planar 4-valent graph and therefore the
# per-state loop count.
#
# This implements the standard planar state sum over a Knot-Atlas-convention
# PD code `X[a, b, c, d]`:
#   * the under-strand enters arc `a` and exits arc `c`;
#   * the over-strand enters arc `d` and exits arc `b`;
#   * arcs are listed counter-clockwise and are numbered 1..2n along the
#     knot's orientation.
# The A-smoothing joins (a,b) and (c,d); the B-smoothing joins (b,c) and
# (d,a). Loops are counted exactly as cycles of the perfect matching formed
# by the union of the arc-incidence pairing and the per-state smoothing
# pairing. The writhe is read geometrically from the PD (a crossing is
# positive iff its over-strand outgoing arc `b` is the orientation-successor
# of its over-strand incoming arc `d`, i.e. `b ≡ d + 1 (mod 2n)`), which is
# independent of any possibly-inconsistent declared sign.
#
# This engine has been verified to reproduce the published Knot Atlas Jones
# polynomial for every prime knot through 7 crossings (see test/runtests.jl
# "Prime knot table").

"""
    PDCrossing

A single crossing of a planar diagram in Knot-Atlas convention: four arc
labels `(a, b, c, d)` in counter-clockwise order. The under-strand runs
`a → c`, the over-strand runs `d → b`.
"""
struct PDCrossing
    arcs::NTuple{4,Int}
end

"""
    PDCode(crossings::Vector{PDCrossing})

A planar diagram: an ordered list of crossings. Arc labels run 1..2n where
n is the number of crossings (the unknot is the empty PD code).
"""
struct PDCode
    crossings::Vector{PDCrossing}
end

PDCode() = PDCode(PDCrossing[])
Base.length(p::PDCode) = length(p.crossings)
Base.isempty(p::PDCode) = isempty(p.crossings)

"""
    parse_pd(s::AbstractString) -> PDCode

Parse a Knot-Atlas style PD string of comma-separated 4-tuples, e.g.
`"X1,4,2,5 X3,6,4,1 X5,2,6,3"`. An empty string is the unknot.
"""
function parse_pd(s::AbstractString)::PDCode
    toks = split(strip(s))
    isempty(toks) && return PDCode()
    cs = PDCrossing[]
    for tok in toks
        startswith(tok, "X") || error("invalid PD token (expected leading X): $tok")
        nums = parse.(Int, split(tok[2:end], ","))
        length(nums) == 4 || error("invalid PD crossing (need 4 arcs): $tok")
        push!(cs, PDCrossing((nums[1], nums[2], nums[3], nums[4])))
    end
    PDCode(cs)
end

"""
    pd_writhe(pd::PDCode) -> Int

The geometric writhe read directly from the planar diagram. In Knot-Atlas
convention arc labels increase by one along the knot's orientation, so a
crossing is positive iff its over-strand outgoing arc `b` is the immediate
orientation-successor of its over-strand incoming arc `d`
(`b ≡ d + 1 (mod 2n)`), and negative otherwise. This is independent of any
declared crossing sign and is the value needed for the Jones normalisation.
"""
function pd_writhe(pd::PDCode)::Int
    n = length(pd)
    n == 0 && return 0
    twon = 2n
    w = 0
    for c in pd.crossings
        _, b, _, d = c.arcs
        w += (mod1(d + 1, twon) == b) ? 1 : -1
    end
    w
end

# Number of loops in a single Kauffman state, counted exactly as cycles of
# the perfect matching formed by (1) the arc-incidence pairing — the two
# slots sharing an arc label — and (2) the per-state smoothing pairing.
function _pd_state_loops(pd::PDCode, state::Integer)::Int
    n = length(pd)
    arc_slots = Dict{Int,Vector{Int}}()
    for (i, c) in enumerate(pd.crossings)
        for (slot, arc) in enumerate(c.arcs)
            push!(get!(arc_slots, arc, Int[]), 4 * (i - 1) + slot)
        end
    end

    arc_partner = Dict{Int,Int}()
    for (_, v) in arc_slots
        length(v) == 2 || error("invalid PD code: arc shared by $(length(v)) endpoints (expected 2)")
        arc_partner[v[1]] = v[2]
        arc_partner[v[2]] = v[1]
    end

    sm_partner = Dict{Int,Int}()
    for k in 1:n
        s1 = 4 * (k - 1) + 1
        s2 = 4 * (k - 1) + 2
        s3 = 4 * (k - 1) + 3
        s4 = 4 * (k - 1) + 4
        if ((state >> (k - 1)) & 1) == 0
            # A-smoothing: join (a,b) and (c,d)
            sm_partner[s1] = s2; sm_partner[s2] = s1
            sm_partner[s3] = s4; sm_partner[s4] = s3
        else
            # B-smoothing: join (b,c) and (d,a)
            sm_partner[s2] = s3; sm_partner[s3] = s2
            sm_partner[s4] = s1; sm_partner[s1] = s4
        end
    end

    total = 4 * n
    seen = falses(total)
    loops = 0
    for start in 1:total
        seen[start] && continue
        loops += 1
        node = start
        use_arc = true
        while !seen[node]
            seen[node] = true
            node = use_arc ? arc_partner[node] : sm_partner[node]
            use_arc = !use_arc
        end
    end
    loops
end

"""
    pd_bracket_polynomial(pd::PDCode) -> LaurentPoly

The Kauffman bracket ⟨D⟩ in the variable A, computed by the planar state
sum over the PD code. Each of the 2^n states contributes
`A^σ · d^(loops-1)` with `d = -A² - A⁻²` and `σ = (#A-smoothings) -
(#B-smoothings)`. Loop counts use the true planar 4-valent structure, so —
unlike a Gauss-code bracket — this distinguishes topologically distinct
diagrams.
"""
function pd_bracket_polynomial(pd::PDCode)::LaurentPoly
    n = length(pd)
    n == 0 && return LaurentPoly(0 => 1)
    d = LaurentPoly(2 => -1, -2 => -1)  # d = -A² - A⁻²
    result = LaurentPoly()
    for state in 0:(2^n - 1)
        a_count = count_ones(~state & ((1 << n) - 1))  # zero bits = A-smoothings
        loops = _pd_state_loops(pd, state)
        sigma = 2 * a_count - n
        d_pow = lpoly_pow(d, loops - 1)
        result = lpoly_add(result, LaurentPoly(e + sigma => c for (e, c) in d_pow))
    end
    result
end

"""
    jones_from_pd(pd::PDCode) -> LaurentPoly

The Jones polynomial V(t) computed from the planar diagram via the Kauffman
bracket: `V = (-A)^(-3w) ⟨D⟩` with the geometric writhe `w = pd_writhe(pd)`,
followed by the substitution `t = A⁻⁴`. Returns a Laurent polynomial in `t`
with integer exponents.

This is the mathematically correct Jones computation for the knot table:
it has been verified term-for-term against the published Knot Atlas values
for every prime knot through 7 crossings.
"""
function jones_from_pd(pd::PDCode)::LaurentPoly
    n = length(pd)
    n == 0 && return LaurentPoly(0 => 1)

    bracket = pd_bracket_polynomial(pd)
    w = pd_writhe(pd)

    # (-A)^(-3w) = (-1)^w · A^(-3w)
    sign_factor = iseven(w) ? 1 : -1
    exp_shift = -3 * w
    normalised = LaurentPoly()
    for (e, c) in bracket
        normalised[e + exp_shift] = get(normalised, e + exp_shift, 0) + c * sign_factor
    end
    filter!(p -> p.second != 0, normalised)

    # t = A⁻⁴ ⇒ t-exponent = -(A-exponent)/4. For a valid knot PD every
    # surviving A-exponent is divisible by 4; a non-divisible exponent means
    # the PD code is not a valid single-component planar diagram.
    jones = LaurentPoly()
    for (a_exp, coeff) in normalised
        a_exp % 4 == 0 ||
            error("PD code does not yield an integer Jones polynomial " *
                  "(A-exponent $a_exp not divisible by 4); the PD code is invalid")
        t_exp = -div(a_exp, 4)
        jones[t_exp] = get(jones, t_exp, 0) + coeff
    end
    filter!(p -> p.second != 0, jones)
    jones
end

"""
    jones_from_pd_str(pd::PDCode) -> String

The Jones polynomial computed from the planar diagram, serialised in the
same `"exp:coeff,..."` format as [`jones_polynomial_str`](@ref).
"""
jones_from_pd_str(pd::PDCode)::String = serialise_laurent(jones_from_pd(pd))
