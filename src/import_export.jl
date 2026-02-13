# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

"""
Import/export for common knot data sources.

Supports bulk import from CSV (KnotInfo-style), and export to
CSV and JSON for interop with other tools.
"""

"""
    bulk_import!(db::SkeinDB, records::Vector{Tuple{String, GaussCode}};
                 metadata=nothing)

Bulk insert knots from a vector of (name, gauss_code) tuples.
Uses a transaction for performance.

# Example
```julia
knots = [
    ("3_1", GaussCode([1, -2, 3, -1, 2, -3])),
    ("4_1", GaussCode([1, -2, 3, -4, 2, -1, 4, -3])),
]
bulk_import!(db, knots)
```
"""
function bulk_import!(db::SkeinDB,
                      records::Vector{Tuple{String, GaussCode}};
                      metadata::Union{Nothing, Dict{String, Dict{String, String}}} = nothing)
    db.readonly && error("Database is read-only")

    for (name, gc) in records
        meta = if !isnothing(metadata) && haskey(metadata, name)
            metadata[name]
        else
            Dict{String, String}()
        end
        store!(db, name, gc; metadata = meta)
    end
end

"""
    import_csv!(db::SkeinDB, path::String;
                name_col=1, gauss_col=2, delimiter=',')

Import knots from a CSV file. Expects at minimum a name column
and a Gauss code column (as bracket-delimited integer lists).

Additional columns are stored as metadata with the header as key.
"""
function import_csv!(db::SkeinDB, path::String;
                     name_col::Int = 1,
                     gauss_col::Int = 2,
                     delimiter::Char = ',')
    db.readonly && error("Database is read-only")

    lines = readlines(path)
    isempty(lines) && return 0

    # Parse header
    headers = strip.(split(lines[1], delimiter))
    meta_cols = setdiff(1:length(headers), [name_col, gauss_col])

    count = 0
    for line in lines[2:end]
        fields = strip.(split(line, delimiter))
        length(fields) < max(name_col, gauss_col) && continue

        name = fields[name_col]
        gc = deserialise_gauss(fields[gauss_col])

        meta = Dict{String, String}()
        for col in meta_cols
            col <= length(fields) || continue
            meta[headers[col]] = fields[col]
        end

        store!(db, name, gc; metadata = meta)
        count += 1
    end

    count
end

"""
    export_csv(db::SkeinDB, path::String; kwargs...)

Export the database (or a query result) to CSV.
Accepts the same keyword arguments as `query`.
"""
function export_csv(db::SkeinDB, path::String; kwargs...)
    records = if isempty(kwargs)
        list_knots(db; limit = typemax(Int))
    else
        query(db; kwargs...)
    end

    open(path, "w") do io
        println(io, "name,gauss_code,crossing_number,writhe")
        for r in records
            gc_str = serialise_gauss(r.gauss_code)
            println(io, "\"", r.name, "\",\"", gc_str, "\",",
                    r.crossing_number, ",", r.writhe)
        end
    end

    length(records)
end

"""
    import_knotinfo!(db::SkeinDB)

Populate the database with the standard prime knot table up to 7 crossings.
Uses hardcoded Gauss codes for the classical prime knots.

Returns the number of knots imported.
"""
function import_knotinfo!(db::SkeinDB)
    db.readonly && error("Database is read-only")

    # Standard prime knots with their Gauss codes
    # Notation: n_k = k-th prime knot with n crossings
    knots = [
        ("0_1",  Int[],                                      Dict("type" => "trivial", "alternating" => "true")),
        ("3_1",  [1, -2, 3, -1, 2, -3],                     Dict("type" => "torus", "alternating" => "true", "family" => "(2,3)-torus")),
        ("4_1",  [1, -2, 3, -4, 2, -1, 4, -3],              Dict("type" => "twist", "alternating" => "true")),
        ("5_1",  [1, -2, 3, -4, 5, -1, 2, -3, 4, -5],       Dict("type" => "torus", "alternating" => "true", "family" => "(2,5)-torus")),
        ("5_2",  [1, -2, 3, -4, 5, -3, 4, -1, 2, -5],       Dict("type" => "twist", "alternating" => "true")),
        ("6_1",  [1, -2, 3, -4, 5, -6, 4, -3, 6, -1, 2, -5], Dict("type" => "twist", "alternating" => "true", "alias" => "stevedore")),
        ("6_2",  [1, -2, 3, -4, 5, -6, 2, -5, 4, -1, 6, -3], Dict("type" => "alternating", "alternating" => "true")),
        ("6_3",  [1, -2, 3, -4, 5, -6, 4, -1, 6, -3, 2, -5], Dict("type" => "alternating", "alternating" => "true")),
        ("7_1",  [1, -2, 3, -4, 5, -6, 7, -1, 2, -3, 4, -5, 6, -7], Dict("type" => "torus", "alternating" => "true", "family" => "(2,7)-torus")),
    ]

    count = 0
    for (name, gc_data, meta) in knots
        if !haskey(db, name)
            store!(db, name, GaussCode(gc_data); metadata = meta)
            count += 1
        end
    end

    count
end

export import_knotinfo!

"""
    export_json(db::SkeinDB, path::String; kwargs...)

Export knots as a JSON array. Each knot includes its invariants
and metadata. Useful for interop with web tools and visualisers.
"""
function export_json(db::SkeinDB, path::String; kwargs...)
    records = if isempty(kwargs)
        list_knots(db; limit = typemax(Int))
    else
        query(db; kwargs...)
    end

    open(path, "w") do io
        println(io, "[")
        for (i, r) in enumerate(records)
            comma = i < length(records) ? "," : ""
            meta_pairs = join(["\"$k\":\"$v\"" for (k, v) in r.metadata], ",")
            println(io, """  {"name":"$(r.name)",""",
                    """"gauss_code":$(r.gauss_code.crossings),""",
                    """"crossing_number":$(r.crossing_number),""",
                    """"writhe":$(r.writhe),""",
                    """"metadata":{$meta_pairs}}$comma""")
        end
        println(io, "]")
    end

    length(records)
end
