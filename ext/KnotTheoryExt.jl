# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
Extension module activated when KnotTheory.jl is loaded alongside Skein.jl.

This extension keeps the boundary clean:
- KnotTheory.jl computes combinatorial invariants and conversions.
- Skein.jl stores canonical PD serializations and cached invariant values.
"""
module KnotTheoryExt

using KnotTheory
using SHA
using Skein

const PD_SERIAL_PREFIX = "pdv1"

# -- PD serialisation --------------------------------------------------------

function _parse_int_list(chunk::AbstractString)::Vector{Int}
    isempty(chunk) && return Int[]
    parse.(Int, split(chunk, ","))
end

function _serialise_pd(pd::KnotTheory.PlanarDiagram)::String
    crossing_chunks = String[]
    for c in pd.crossings
        a, b, d, e = c.arcs
        push!(crossing_chunks, string(a, ",", b, ",", d, ",", e, ",", c.sign))
    end

    component_chunks = String[]
    for comp in pd.components
        push!(component_chunks, join(comp, ","))
    end

    string(PD_SERIAL_PREFIX,
           "|x=", join(crossing_chunks, ";"),
           "|c=", join(component_chunks, ";"))
end

function _deserialise_pd(blob::AbstractString)::KnotTheory.PlanarDiagram
    parts = split(String(blob), "|")
    length(parts) == 3 || error("Invalid PD blob: expected 3 pipe-delimited sections")
    parts[1] == PD_SERIAL_PREFIX || error("Unsupported PD serialization version: $(parts[1])")
    startswith(parts[2], "x=") || error("Invalid PD blob: missing crossing payload")
    startswith(parts[3], "c=") || error("Invalid PD blob: missing component payload")

    crossings_payload = parts[2][3:end]
    components_payload = parts[3][3:end]

    entries = NTuple{5, Int}[]
    if !isempty(crossings_payload)
        for token in split(crossings_payload, ";")
            vals = _parse_int_list(token)
            length(vals) == 5 || error("Invalid crossing token '$token'")
            push!(entries, (vals[1], vals[2], vals[3], vals[4], vals[5]))
        end
    end

    components = Vector{Vector{Int}}()
    if !isempty(components_payload)
        for token in split(components_payload, ";")
            push!(components, _parse_int_list(token))
        end
    end

    KnotTheory.pdcode(entries; components = components)
end

function _canonicalise_pd(pd::KnotTheory.PlanarDiagram)::KnotTheory.PlanarDiagram
    if isempty(pd.crossings)
        return KnotTheory.pdcode(NTuple{5, Int}[]; components = copy(pd.components))
    end

    arcs = Int[]
    for c in pd.crossings
        append!(arcs, c.arcs)
    end
    unique_arcs = sort(unique(arcs))
    arc_map = Dict{Int, Int}(arc => idx for (idx, arc) in enumerate(unique_arcs))

    entries = NTuple{5, Int}[]
    for c in pd.crossings
        a, b, d, e = c.arcs
        push!(entries, (arc_map[a], arc_map[b], arc_map[d], arc_map[e], c.sign))
    end
    sort!(entries)

    components = Vector{Vector{Int}}()
    for comp in pd.components
        mapped = [get(arc_map, arc, arc) for arc in comp]
        sort!(mapped)
        push!(components, mapped)
    end
    sort!(components, by = c -> join(c, ","))

    KnotTheory.pdcode(entries; components = components)
end

function _canonical_pd_blob(pd::KnotTheory.PlanarDiagram)::String
    _serialise_pd(_canonicalise_pd(pd))
end

# -- Invariant serialisation -------------------------------------------------

function _serialise_int_poly(poly)::String
    pairs = String[]
    for exp in sort(collect(keys(poly)))
        coeff = poly[exp]
        coeff == 0 && continue
        push!(pairs, string(exp, ":", coeff))
    end
    isempty(pairs) ? "0:0" : join(pairs, ",")
end

# -- Conversion helpers ------------------------------------------------------

function _dt_to_crossings(dt::Vector{Int})::Vector{Int}
    n = length(dt)
    n == 0 && return Int[]

    gauss = Vector{Int}(undef, 2n)
    for i in 1:n
        odd_pos = 2i - 1
        even_pos = abs(dt[i])
        if dt[i] > 0
            gauss[odd_pos] = i
            gauss[even_pos] = -i
        else
            gauss[odd_pos] = -i
            gauss[even_pos] = i
        end
    end
    gauss
end

"""
    pd_to_gauss(pd::KnotTheory.PlanarDiagram) -> GaussCode

Best-effort conversion through DT when possible. Falls back to a deterministic
diagram-level encoding when the Dowker conversion assumptions are not met.
"""
function pd_to_gauss(pd::KnotTheory.PlanarDiagram)::Skein.GaussCode
    isempty(pd.crossings) && return Skein.GaussCode(Int[])

    try
        dt = KnotTheory.to_dowker(pd)
        raw = _dt_to_crossings(dt)
        Skein.validate_gauss_code(raw) || error("Derived Gauss code failed validation")
        return Skein.GaussCode(raw)
    catch
        # Deterministic fallback preserving crossing signs.
        gauss = Int[]
        for (i, c) in enumerate(pd.crossings)
            if c.sign >= 0
                push!(gauss, i, -i)
            else
                push!(gauss, -i, i)
            end
        end
        return Skein.GaussCode(gauss)
    end
end

function _pd_cached_values(pd::KnotTheory.PlanarDiagram)
    cn = length(pd.crossings)
    wr = sum(c.sign for c in pd.crossings)
    seifert = KnotTheory.seifert_circles(pd)
    genus = max(0, (cn - seifert + 1) ÷ 2)
    alex = _serialise_int_poly(KnotTheory.alexander_polynomial(pd))
    jones = _serialise_int_poly(KnotTheory.jones_polynomial(pd; wr = wr))
    det = KnotTheory.determinant(pd)
    sig = KnotTheory.signature(pd)
    (cn, wr, seifert, genus, alex, jones, det, sig)
end

function _store_pd!(db::Skein.SkeinDB, name::String, pd::KnotTheory.PlanarDiagram;
                    metadata::Dict{String, String}, source_type::String)
    gauss = pd_to_gauss(pd)
    pd_blob = _serialise_pd(pd)
    canonical_blob = _canonical_pd_blob(pd)
    cn, wr, seifert, genus, alex, jones, det, sig = _pd_cached_values(pd)
    content_hash = bytes2hex(sha256(canonical_blob))

    enriched_metadata = copy(metadata)
    enriched_metadata["source_type"] = source_type
    enriched_metadata["serialization"] = "pdv1"

    Skein._store_precomputed!(db, name, gauss;
                              metadata = enriched_metadata,
                              diagram_format = "pd",
                              canonical_diagram = canonical_blob,
                              pd_code = pd_blob,
                              crossing_number_value = cn,
                              writhe_value = wr,
                              gauss_hash_value = content_hash,
                              alexander_polynomial = alex,
                              jones_polynomial = jones,
                              determinant = det,
                              signature = sig,
                              genus = genus,
                              seifert_circle_count = seifert)
end

# -- Public adapter methods --------------------------------------------------

"""
    Skein.store!(db::SkeinDB, name::String, knot::KnotTheory.Knot; metadata=Dict())

Store a KnotTheory knot using canonical PD serialisation and cached invariants
computed by KnotTheory.jl.
"""
function Skein.store!(db::Skein.SkeinDB, name::String, knot::KnotTheory.Knot;
                      metadata::Dict{String, String} = Dict{String, String}())
    knot.pd === nothing && error("Cannot store KnotTheory.Knot without a planar diagram")
    _store_pd!(db, name, knot.pd; metadata = metadata, source_type = "KnotTheory.Knot")
end

"""
    Skein.store!(db::SkeinDB, name::String, pd::KnotTheory.PlanarDiagram; metadata=Dict())

Store a KnotTheory planar diagram directly in Skein.
"""
function Skein.store!(db::Skein.SkeinDB, name::String, pd::KnotTheory.PlanarDiagram;
                      metadata::Dict{String, String} = Dict{String, String}())
    _store_pd!(db, name, pd; metadata = metadata, source_type = "KnotTheory.PlanarDiagram")
end

"""
    Skein.to_planardiagram(record::Skein.KnotRecord) -> KnotTheory.PlanarDiagram

Reconstruct a planar diagram from a Skein record that has PD serialisation.
"""
function Skein.to_planardiagram(record::Skein.KnotRecord)::KnotTheory.PlanarDiagram
    blob = if !isnothing(record.pd_code)
        record.pd_code
    elseif !isnothing(record.canonical_diagram)
        record.canonical_diagram
    else
        error("Record '$(record.name)' does not contain PD serialisation")
    end

    _deserialise_pd(blob)
end

"""
    Skein.to_knot(record::Skein.KnotRecord) -> KnotTheory.Knot

Reconstruct a KnotTheory knot from a Skein record.
"""
function Skein.to_knot(record::Skein.KnotRecord)::KnotTheory.Knot
    pd = Skein.to_planardiagram(record)
    dt = try
        KnotTheory.DTCode(KnotTheory.to_dowker(pd))
    catch
        nothing
    end

    KnotTheory.Knot(Symbol(record.name), pd, dt)
end

end # module KnotTheoryExt
