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

    # Parse header (no quoted fields expected in header)
    headers = strip.(split(lines[1], delimiter))
    meta_cols = setdiff(1:length(headers), [name_col, gauss_col])

    count = 0
    for line in lines[2:end]
        fields = _parse_csv_line(line, delimiter)
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

"""Parse a CSV line, respecting double-quoted fields (which may contain the delimiter)."""
function _parse_csv_line(line::AbstractString, delim::Char)::Vector{String}
    fields = String[]
    i = 1
    n = length(line)

    while i <= n
        if line[i] == '"'
            # Quoted field: scan to closing quote
            j = i + 1
            while j <= n
                if line[j] == '"'
                    if j + 1 <= n && line[j + 1] == '"'
                        j += 2  # escaped quote
                    else
                        break
                    end
                else
                    j += 1
                end
            end
            push!(fields, strip(line[i+1:j-1]))
            # Skip closing quote and delimiter
            i = j + 1
            i <= n && line[i] == delim && (i += 1)
        else
            # Unquoted field: scan to delimiter
            j = findnext(==(delim), line, i)
            if isnothing(j)
                push!(fields, strip(line[i:end]))
                break
            else
                push!(fields, strip(line[i:j-1]))
                i = j + 1
            end
        end
    end

    fields
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
    dt_to_gauss(dt::Vector{Int}) -> GaussCode

Convert Dowker-Thistlethwaite notation to a Gauss code.

DT notation for an n-crossing knot is a vector of n signed even integers.
Entry `dt[i]` pairs odd crossing label `2i-1` with even label `|dt[i]|`.
Positive entries indicate the odd-labeled strand goes over at that crossing;
negative entries indicate it goes under (used for non-alternating knots).

# Example
```julia
dt_to_gauss([4, 6, 2])  # trefoil 3_1
dt_to_gauss([4, 6, 8, 2])  # figure-eight 4_1
```
"""
function dt_to_gauss(dt::Vector{Int})::GaussCode
    n = length(dt)
    n == 0 && return GaussCode(Int[])

    gauss = Vector{Int}(undef, 2n)

    for i in 1:n
        odd_pos = 2i - 1
        even_pos = abs(dt[i])

        if dt[i] > 0
            # Odd-labeled strand goes over at this crossing
            gauss[odd_pos] = i
            gauss[even_pos] = -i
        else
            # Odd-labeled strand goes under at this crossing
            gauss[odd_pos] = -i
            gauss[even_pos] = i
        end
    end

    GaussCode(gauss)
end

"""
    import_knotinfo!(db::SkeinDB)

Populate the database with the standard prime knot table through 8 crossings
(36 knots: the Rolfsen table). Uses Dowker-Thistlethwaite notation internally.

Returns the number of knots imported. Idempotent — re-calling skips
knots already present.
"""
function import_knotinfo!(db::SkeinDB)
    db.readonly && error("Database is read-only")

    # Standard prime knots from the Rolfsen table
    # Format: (name, DT_notation, metadata)
    # DT notation: signed even integers per Dowker-Thistlethwaite convention
    knot_data = [
        # -- 0 crossings --
        ("0_1",  Int[],
         Dict("type" => "trivial", "alternating" => "true")),

        # -- 3 crossings --
        ("3_1",  [4, 6, 2],
         Dict("type" => "torus", "alternating" => "true", "family" => "(2,3)-torus")),

        # -- 4 crossings --
        ("4_1",  [4, 6, 8, 2],
         Dict("type" => "twist", "alternating" => "true", "alias" => "figure-eight")),

        # -- 5 crossings --
        ("5_1",  [6, 8, 10, 2, 4],
         Dict("type" => "torus", "alternating" => "true", "family" => "(2,5)-torus")),
        ("5_2",  [4, 8, 10, 2, 6],
         Dict("type" => "twist", "alternating" => "true")),

        # -- 6 crossings --
        ("6_1",  [4, 8, 12, 2, 10, 6],
         Dict("type" => "twist", "alternating" => "true", "alias" => "stevedore")),
        ("6_2",  [4, 8, 10, 12, 2, 6],
         Dict("type" => "alternating", "alternating" => "true")),
        ("6_3",  [4, 8, 10, 2, 12, 6],
         Dict("type" => "alternating", "alternating" => "true")),

        # -- 7 crossings --
        ("7_1",  [8, 10, 12, 14, 2, 4, 6],
         Dict("type" => "torus", "alternating" => "true", "family" => "(2,7)-torus")),
        ("7_2",  [4, 10, 14, 12, 2, 8, 6],
         Dict("type" => "alternating", "alternating" => "true")),
        ("7_3",  [4, 10, 12, 14, 2, 6, 8],
         Dict("type" => "alternating", "alternating" => "true")),
        ("7_4",  [4, 8, 12, 2, 14, 6, 10],
         Dict("type" => "alternating", "alternating" => "true")),
        ("7_5",  [6, 8, 12, 14, 4, 2, 10],
         Dict("type" => "alternating", "alternating" => "true")),
        ("7_6",  [4, 8, 14, 2, 12, 6, 10],
         Dict("type" => "alternating", "alternating" => "true")),
        ("7_7",  [4, 8, 12, 14, 2, 10, 6],
         Dict("type" => "alternating", "alternating" => "true")),

        # -- 8 crossings (alternating) --
        ("8_1",  [4, 10, 16, 14, 2, 12, 8, 6],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_2",  [4, 10, 12, 16, 2, 14, 8, 6],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_3",  [4, 10, 16, 12, 2, 14, 6, 8],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_4",  [4, 8, 14, 16, 2, 12, 6, 10],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_5",  [6, 8, 14, 16, 4, 12, 2, 10],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_6",  [4, 8, 12, 2, 16, 14, 6, 10],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_7",  [4, 8, 14, 2, 16, 6, 12, 10],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_8",  [4, 10, 14, 16, 2, 12, 6, 8],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_9",  [4, 8, 14, 16, 2, 10, 6, 12],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_10", [4, 8, 14, 2, 16, 10, 6, 12],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_11", [6, 8, 14, 16, 4, 2, 12, 10],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_12", [4, 8, 14, 16, 12, 2, 10, 6],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_13", [4, 8, 12, 16, 14, 2, 10, 6],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_14", [4, 8, 14, 16, 2, 6, 12, 10],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_15", [4, 10, 16, 14, 12, 2, 8, 6],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_16", [4, 10, 14, 16, 12, 2, 6, 8],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_17", [4, 8, 16, 14, 12, 2, 10, 6],
         Dict("type" => "alternating", "alternating" => "true")),
        ("8_18", [4, 8, 16, 2, 14, 12, 6, 10],
         Dict("type" => "alternating", "alternating" => "true",
              "alias" => "knot-18")),

        # -- 8 crossings (non-alternating) --
        ("8_19", [4, 8, -12, 2, -16, -14, 6, 10],
         Dict("type" => "non-alternating", "alternating" => "false")),
        ("8_20", [4, 8, -14, 2, -16, 6, -12, 10],
         Dict("type" => "non-alternating", "alternating" => "false")),
        ("8_21", [4, -10, 16, -14, 2, -12, 8, 6],
         Dict("type" => "non-alternating", "alternating" => "false")),
    ]

    count = 0
    for (name, dt, meta) in knot_data
        if !haskey(db, name)
            gc = dt_to_gauss(dt)
            store!(db, name, gc; metadata = meta)
            count += 1
        end
    end

    count
end

export import_knotinfo!, dt_to_gauss

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
