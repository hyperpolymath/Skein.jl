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
- `genus`: Int, UnitRange, or Vector{Int}
- `gauss_hash`: String (exact match)
- `name_like`: String (SQL LIKE pattern, e.g. "torus%")
- `meta`: Pair{String,String} — match a metadata key-value pair
- `limit`: Int (default 100)
- `offset`: Int (default 0)
"""
function query(db::SkeinDB;
               crossing_number = nothing,
               writhe = nothing,
               genus = nothing,
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

    if !isnothing(genus)
        cond, ps = build_condition("k.genus", genus)
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

"""
    find_equivalents(db::SkeinDB, g::GaussCode) -> Vector{KnotRecord}

Find all knots in the database whose Gauss code is equivalent to `g`
(same diagram up to cyclic rotation and relabelling).
"""
function find_equivalents(db::SkeinDB, g::GaussCode)::Vector{KnotRecord}
    cn = crossing_number(g)
    candidates = query(db, crossing_number = cn)
    filter(r -> is_equivalent(r.gauss_code, g), candidates)
end

"""
    find_isotopic(db::SkeinDB, g::GaussCode) -> Vector{KnotRecord}

Find all knots in the database that are topologically equivalent to `g`
(after Reidemeister I simplification + cyclic rotation + relabelling).
"""
function find_isotopic(db::SkeinDB, g::GaussCode)::Vector{KnotRecord}
    s = simplify_r1(g)
    cn = crossing_number(s)
    # Check knots with same or fewer crossings (R1 can reduce crossing number)
    candidates = query(db, crossing_number = 0:max(cn, crossing_number(g)))
    filter(r -> is_isotopic(r.gauss_code, g), candidates)
end

# -- Composable query predicates --

"""
    QueryPredicate

Abstract type for composable query predicates. Supports `&` (AND) and `|` (OR)
composition for building complex queries.

# Examples
```julia
# Compose with & and |
q = (crossing(3) | crossing(4)) & writhe_eq(0)
results = query(db, q)
```
"""
abstract type QueryPredicate end

struct CrossingPred <: QueryPredicate
    value::Any  # Int, UnitRange, or Vector{Int}
end

struct WrithePred <: QueryPredicate
    value::Any
end

struct GenusPred <: QueryPredicate
    value::Any
end

struct MetaPred <: QueryPredicate
    key::String
    value::String
end

struct NamePred <: QueryPredicate
    pattern::String
end

struct AndPred <: QueryPredicate
    left::QueryPredicate
    right::QueryPredicate
end

struct OrPred <: QueryPredicate
    left::QueryPredicate
    right::QueryPredicate
end

# Constructors
crossing(v) = CrossingPred(v)
writhe_eq(v) = WrithePred(v)
genus_eq(v) = GenusPred(v)
meta_eq(k, v) = MetaPred(k, v)
name_like(p) = NamePred(p)

# Composition operators
Base.:(&)(a::QueryPredicate, b::QueryPredicate) = AndPred(a, b)
Base.:(|)(a::QueryPredicate, b::QueryPredicate) = OrPred(a, b)

"""
    query(db::SkeinDB, pred::QueryPredicate; limit=100, offset=0) -> Vector{KnotRecord}

Query knots using composable predicates built with `crossing()`, `writhe_eq()`,
`meta_eq()`, `name_like()`, and combined with `&` (AND) and `|` (OR).
"""
function query(db::SkeinDB, pred::QueryPredicate; limit::Int = 100, offset::Int = 0)
    results = list_knots(db; limit = typemax(Int))
    filtered = filter(r -> evaluate_predicate(pred, r), results)

    # Apply pagination
    start = min(offset + 1, length(filtered) + 1)
    stop = min(offset + limit, length(filtered))
    start > stop ? KnotRecord[] : filtered[start:stop]
end

function evaluate_predicate(p::CrossingPred, r::KnotRecord)::Bool
    _match_value(r.crossing_number, p.value)
end

function evaluate_predicate(p::WrithePred, r::KnotRecord)::Bool
    _match_value(r.writhe, p.value)
end

function evaluate_predicate(p::GenusPred, r::KnotRecord)::Bool
    isnothing(r.genus) && return false
    _match_value(r.genus, p.value)
end

function evaluate_predicate(p::MetaPred, r::KnotRecord)::Bool
    get(r.metadata, p.key, "") == p.value
end

function evaluate_predicate(p::NamePred, r::KnotRecord)::Bool
    # Simple pattern matching (SQL LIKE -> Julia)
    pattern = replace(p.pattern, "%" => ".*", "_" => ".")
    occursin(Regex("^" * pattern * "\$"), r.name)
end

function evaluate_predicate(p::AndPred, r::KnotRecord)::Bool
    evaluate_predicate(p.left, r) && evaluate_predicate(p.right, r)
end

function evaluate_predicate(p::OrPred, r::KnotRecord)::Bool
    evaluate_predicate(p.left, r) || evaluate_predicate(p.right, r)
end

function _match_value(actual::Int, expected::Int)
    actual == expected
end

function _match_value(actual::Int, expected::UnitRange{Int})
    actual in expected
end

function _match_value(actual::Int, expected::Vector{Int})
    actual in expected
end

function _match_value(actual::Int, expected::StepRange{Int, Int})
    actual in expected
end
