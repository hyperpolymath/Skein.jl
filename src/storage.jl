# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

"""
SQLite storage backend for Skein.jl

Schema is deliberately simple — one table for knots, one for metadata
key-value pairs. Invariants are stored as indexed columns for fast
filtering. The Gauss code itself is stored as a JSON array of integers.
"""

const SCHEMA_VERSION = 1

const CREATE_TABLES = """
CREATE TABLE IF NOT EXISTS knots (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    gauss_code  TEXT NOT NULL,
    crossing_number INTEGER NOT NULL,
    writhe      INTEGER NOT NULL,
    gauss_hash  TEXT NOT NULL,
    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS knot_metadata (
    knot_id TEXT NOT NULL,
    key     TEXT NOT NULL,
    value   TEXT NOT NULL,
    PRIMARY KEY (knot_id, key),
    FOREIGN KEY (knot_id) REFERENCES knots(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS schema_info (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_knots_crossing ON knots(crossing_number);
CREATE INDEX IF NOT EXISTS idx_knots_writhe ON knots(writhe);
CREATE INDEX IF NOT EXISTS idx_knots_hash ON knots(gauss_hash);
CREATE INDEX IF NOT EXISTS idx_metadata_key ON knot_metadata(key);
"""

"""
    SkeinDB(path::String; readonly=false)

Open or create a Skein database at the given file path.
Use `:memory:` for an in-memory database (useful for testing).

# Examples
```julia
db = SkeinDB("knots.db")
db = SkeinDB(":memory:")
```
"""
mutable struct SkeinDB
    conn::SQLite.DB
    path::String
    readonly::Bool

    function SkeinDB(path::String; readonly::Bool = false)
        conn = SQLite.DB(path)

        # Enable WAL mode for better concurrent read performance
        DBInterface.execute(conn, "PRAGMA journal_mode=WAL")
        DBInterface.execute(conn, "PRAGMA foreign_keys=ON")

        if !readonly
            # Create tables if they don't exist
            for stmt in split(CREATE_TABLES, ";")
                stripped = strip(stmt)
                isempty(stripped) || DBInterface.execute(conn, stripped)
            end

            # Record schema version
            DBInterface.execute(conn,
                "INSERT OR REPLACE INTO schema_info (key, value) VALUES ('version', ?)",
                [string(SCHEMA_VERSION)])
        end

        new(conn, path, readonly)
    end
end

Base.isopen(db::SkeinDB) = isopen(db.conn)

function Base.close(db::SkeinDB)
    close(db.conn)
end

function Base.show(io::IO, db::SkeinDB)
    n = count_knots(db)
    status = isopen(db) ? "open" : "closed"
    print(io, "SkeinDB(\"", db.path, "\", ", n, " knots, ", status, ")")
end

function count_knots(db::SkeinDB)::Int
    for row in DBInterface.execute(db.conn, "SELECT COUNT(*) as n FROM knots")
        return Int(row[:n])
    end
    return 0
end

# -- Serialisation helpers --

function serialise_gauss(g::GaussCode)::String
    "[" * join(g.crossings, ",") * "]"
end

function deserialise_gauss(s::String)::GaussCode
    # Parse "[1,-2,3,-1,2,-3]" back to Vector{Int}
    stripped = strip(s, ['[', ']'])
    isempty(stripped) && return GaussCode(Int[])
    crossings = parse.(Int, split(stripped, ","))
    GaussCode(crossings)
end

# -- Core CRUD --

"""
    store!(db::SkeinDB, name::String, g::GaussCode; metadata=Dict())

Store a knot in the database. Invariants are computed automatically.
Throws an error if a knot with the same name already exists.

# Example
```julia
store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]),
       metadata = Dict("family" => "torus", "notation" => "3_1"))
```
"""
function store!(db::SkeinDB, name::String, g::GaussCode;
                metadata::Dict{String, String} = Dict{String, String}())
    db.readonly && error("Database is read-only")

    id = string(uuid4())
    cn = crossing_number(g)
    w = writhe(g)
    h = gauss_hash(g)
    code_str = serialise_gauss(g)
    now = string(Dates.now())

    DBInterface.execute(db.conn,
        """INSERT INTO knots (id, name, gauss_code, crossing_number, writhe, gauss_hash, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
        [id, name, code_str, cn, w, h, now, now])

    for (k, v) in metadata
        DBInterface.execute(db.conn,
            "INSERT INTO knot_metadata (knot_id, key, value) VALUES (?, ?, ?)",
            [id, k, v])
    end

    id
end

"""
    fetch_knot(db::SkeinDB, name::String) -> Union{KnotRecord, Nothing}

Retrieve a knot by name. Returns `nothing` if not found.
"""
function fetch_knot(db::SkeinDB, name::String)::Union{KnotRecord, Nothing}
    result = DBInterface.execute(db.conn,
        "SELECT * FROM knots WHERE name = ?", [name])

    for row in result
        id = string(row[:id])
        meta = fetch_metadata(db, id)
        return KnotRecord(
            id,
            string(row[:name]),
            deserialise_gauss(string(row[:gauss_code])),
            Int(row[:crossing_number]),
            Int(row[:writhe]),
            string(row[:gauss_hash]),
            meta,
            DateTime(string(row[:created_at])),
            DateTime(string(row[:updated_at]))
        )
    end

    return nothing
end

function fetch_metadata(db::SkeinDB, knot_id::String)::Dict{String, String}
    result = DBInterface.execute(db.conn,
        "SELECT key, value FROM knot_metadata WHERE knot_id = ?", [knot_id])
    Dict(string(row[:key]) => string(row[:value]) for row in result)
end

"""
    Base.delete!(db::SkeinDB, name::String)

Remove a knot and its metadata from the database.
"""
function Base.delete!(db::SkeinDB, name::String)
    db.readonly && error("Database is read-only")
    DBInterface.execute(db.conn, "DELETE FROM knots WHERE name = ?", [name])
end

"""
    list_knots(db::SkeinDB; limit=100, offset=0) -> Vector{KnotRecord}

List knots in the database with pagination.
"""
function list_knots(db::SkeinDB; limit::Int = 100, offset::Int = 0)::Vector{KnotRecord}
    result = DBInterface.execute(db.conn,
        "SELECT * FROM knots ORDER BY name LIMIT ? OFFSET ?",
        [limit, offset])

    [row_to_record(db, row) for row in result]
end

"""
    update_metadata!(db::SkeinDB, name::String, metadata::Dict{String, String})

Merge metadata into an existing knot record. Existing keys are overwritten.
"""
function update_metadata!(db::SkeinDB, name::String, metadata::Dict{String, String})
    db.readonly && error("Database is read-only")

    record = fetch_knot(db, name)
    isnothing(record) && error("Knot '$name' not found")

    for (k, v) in metadata
        DBInterface.execute(db.conn,
            "INSERT OR REPLACE INTO knot_metadata (knot_id, key, value) VALUES (?, ?, ?)",
            [record.id, k, v])
    end

    # Touch updated_at
    DBInterface.execute(db.conn,
        "UPDATE knots SET updated_at = ? WHERE id = ?",
        [string(Dates.now()), record.id])
end

# -- Internal helpers --

function row_to_record(db::SkeinDB, row)::KnotRecord
    id = string(row[:id])
    meta = fetch_metadata(db, id)
    KnotRecord(
        id,
        string(row[:name]),
        deserialise_gauss(string(row[:gauss_code])),
        Int(row[:crossing_number]),
        Int(row[:writhe]),
        string(row[:gauss_hash]),
        meta,
        DateTime(string(row[:created_at])),
        DateTime(string(row[:updated_at]))
    )
end
