# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

"""
Query interface for Skein.jl

Queries are built from keyword arguments that map to invariant columns.
Supports exact values, ranges, and sets. Composable with Julia's
standard iteration and filtering patterns.

# Examples
```julia
# Exact match
query(db, crossing_number = 3)

# Range query
query(db, crossing_number = 3:7)

# Multiple constraints
query(db, crossing_number = 3:7, writhe = 0)

# By metadata
query(db, meta = ("family" => "torus"))

# By hash (deduplication check)
query(db, gauss_hash = gauss_hash(some_code))
```
"""

"""
    query(db::SkeinDB; kwargs...) -> Vector{KnotRecord}

Query knots by invariant values. Supported keyword arguments:

- `crossing_number`: Int, UnitRange, or Vector{Int}
- `writhe`: Int, UnitRange, or Vector{Int}
- `gauss_hash`: String (exact match)
- `name_like`: String (SQL LIKE pattern, e.g. "torus%")
- `meta`: Pair{String,String} — match a metadata key-value pair
- `limit`: Int (default 100)
- `offset`: Int (default 0)
"""
function query(db::SkeinDB;
               crossing_number = nothing,
               writhe = nothing,
               gauss_hash = nothing,
               name_like = nothing,
               meta = nothing,
               limit::Int = 100,
               offset::Int = 0)::Vector{KnotRecord}

    conditions = String[]
    params = Any[]
    joins = String[]

    if !isnothing(crossing_number)
        cond, ps = build_condition("k.crossing_number", crossing_number)
        push!(conditions, cond)
        append!(params, ps)
    end

    if !isnothing(writhe)
        cond, ps = build_condition("k.writhe", writhe)
        push!(conditions, cond)
        append!(params, ps)
    end

    if !isnothing(gauss_hash)
        push!(conditions, "k.gauss_hash = ?")
        push!(params, gauss_hash)
    end

    if !isnothing(name_like)
        push!(conditions, "k.name LIKE ?")
        push!(params, name_like)
    end

    if !isnothing(meta)
        push!(joins, "JOIN knot_metadata m ON k.id = m.knot_id")
        push!(conditions, "m.key = ? AND m.value = ?")
        push!(params, meta.first)
        push!(params, meta.second)
    end

    where_clause = isempty(conditions) ? "" : "WHERE " * join(conditions, " AND ")
    join_clause = join(joins, " ")

    sql = """
        SELECT k.* FROM knots k
        $join_clause
        $where_clause
        ORDER BY k.crossing_number, k.name
        LIMIT ? OFFSET ?
    """
    push!(params, limit)
    push!(params, offset)

    result = DBInterface.execute(db.conn, sql, params)
    [row_to_record(db, row) for row in result]
end

# -- Condition builders for different value types --

function build_condition(column::String, value::Int)
    ("$column = ?", Any[value])
end

function build_condition(column::String, range::UnitRange{Int})
    ("$column BETWEEN ? AND ?", Any[first(range), last(range)])
end

function build_condition(column::String, values::Vector{Int})
    placeholders = join(fill("?", length(values)), ", ")
    ("$column IN ($placeholders)", Any[values...])
end

function build_condition(column::String, range::StepRange{Int, Int})
    # For step ranges, expand to explicit values
    vals = collect(range)
    build_condition(column, vals)
end

# -- Convenience queries --

"""
    exists(db::SkeinDB, name::String) -> Bool

Check whether a knot with the given name exists in the database.
"""
function Base.haskey(db::SkeinDB, name::String)::Bool
    for _ in DBInterface.execute(db.conn,
        "SELECT 1 FROM knots WHERE name = ? LIMIT 1", [name])
        return true
    end
    return false
end

"""
    duplicates(db::SkeinDB) -> Vector{Vector{KnotRecord}}

Find groups of knots that share the same Gauss hash
(identical diagrams stored under different names).
"""
function duplicates(db::SkeinDB)::Vector{Vector{KnotRecord}}
    result = DBInterface.execute(db.conn,
        """SELECT gauss_hash, COUNT(*) as n FROM knots
           GROUP BY gauss_hash HAVING n > 1""")

    groups = Vector{KnotRecord}[]
    for row in result
        knots = query(db, gauss_hash = row[:gauss_hash])
        push!(groups, knots)
    end
    groups
end

"""
    statistics(db::SkeinDB) -> NamedTuple

Return summary statistics about the database contents.
"""
function statistics(db::SkeinDB)
    total = count_knots(db)

    mn_val = nothing
    mx_val = nothing
    if total > 0
        for row in DBInterface.execute(db.conn,
            "SELECT MIN(crossing_number) as mn, MAX(crossing_number) as mx FROM knots")
            mn_val = ismissing(row[:mn]) ? nothing : Int(row[:mn])
            mx_val = ismissing(row[:mx]) ? nothing : Int(row[:mx])
        end
    end

    distribution = Dict{Int, Int}()
    for row in DBInterface.execute(db.conn,
        """SELECT crossing_number, COUNT(*) as n FROM knots
           GROUP BY crossing_number ORDER BY crossing_number""")
        distribution[Int(row[:crossing_number])] = Int(row[:n])
    end

    (
        total_knots = total,
        min_crossings = mn_val,
        max_crossings = mx_val,
        crossing_distribution = distribution
    )
end
