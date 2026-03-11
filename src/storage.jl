# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

"""
SQLite storage backend for Skein.jl

Schema is deliberately simple — one table for knots, one for metadata
key-value pairs. Invariants are stored as indexed columns for fast
filtering. The Gauss code itself is stored as a JSON array of integers.
"""

const SCHEMA_VERSION = 3

const CREATE_TABLES = """
CREATE TABLE IF NOT EXISTS knots (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    gauss_code      TEXT NOT NULL,
    crossing_number INTEGER NOT NULL,
    writhe          INTEGER NOT NULL,
    gauss_hash      TEXT NOT NULL,
    jones_polynomial TEXT,
    genus           INTEGER,
    seifert_circles INTEGER,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
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
CREATE INDEX IF NOT EXISTS idx_knots_jones ON knots(jones_polynomial);
CREATE INDEX IF NOT EXISTS idx_knots_genus ON knots(genus);
CREATE INDEX IF NOT EXISTS idx_metadata_key ON knot_metadata(key);
"""

const MIGRATE_V1_TO_V2 = """
ALTER TABLE knots ADD COLUMN jones_polynomial TEXT;
CREATE INDEX IF NOT EXISTS idx_knots_jones ON knots(jones_polynomial);
"""

const MIGRATE_V2_TO_V3 = """
ALTER TABLE knots ADD COLUMN genus INTEGER;
ALTER TABLE knots ADD COLUMN seifert_circles INTEGER;
CREATE INDEX IF NOT EXISTS idx_knots_genus ON knots(genus);
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

            # Check for schema migration
            current_version = _get_schema_version(conn)
            if current_version < 2
                _migrate_v1_to_v2(conn)
            end
            if current_version < 3
                _migrate_v2_to_v3(conn)
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

function deserialise_gauss(s::AbstractString)::GaussCode
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
# Maximum crossing number for auto-computing Jones polynomial on store.
# Jones computation is O(2^n), so we cap it to keep store! responsive.
const MAX_CROSSINGS_FOR_AUTO_JONES = 15

function store!(db::SkeinDB, name::String, g::GaussCode;
                metadata::Dict{String, String} = Dict{String, String}(),
                jones_polynomial::Union{String, Nothing} = nothing)
    db.readonly && error("Database is read-only")

    id = string(uuid4())
    cn = crossing_number(g)
    w = writhe(g)
    h = gauss_hash(g)
    code_str = serialise_gauss(g)
    now = string(Dates.now())

    # Auto-compute Jones polynomial if not provided and crossing count is manageable
    jp = jones_polynomial
    if jp === nothing && cn <= MAX_CROSSINGS_FOR_AUTO_JONES
        jp = jones_polynomial_str(g)
    end

    # Compute Seifert circles and genus
    sc = length(seifert_circles(g))
    gen = genus(g)

    DBInterface.execute(db.conn,
        """INSERT INTO knots (id, name, gauss_code, crossing_number, writhe, gauss_hash,
           jones_polynomial, genus, seifert_circles, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        [id, name, code_str, cn, w, h,
         jp === nothing ? missing : jp,
         gen, sc, now, now])

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
        jp = ismissing(row[:jones_polynomial]) ? nothing : string(row[:jones_polynomial])
        gen = ismissing(row[:genus]) ? nothing : Int(row[:genus])
        sc = ismissing(row[:seifert_circles]) ? nothing : Int(row[:seifert_circles])
        return KnotRecord(
            id,
            string(row[:name]),
            deserialise_gauss(string(row[:gauss_code])),
            Int(row[:crossing_number]),
            Int(row[:writhe]),
            string(row[:gauss_hash]),
            jp,
            gen,
            sc,
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
    jp = ismissing(row[:jones_polynomial]) ? nothing : string(row[:jones_polynomial])
    gen = ismissing(row[:genus]) ? nothing : Int(row[:genus])
    sc = ismissing(row[:seifert_circles]) ? nothing : Int(row[:seifert_circles])
    KnotRecord(
        id,
        string(row[:name]),
        deserialise_gauss(string(row[:gauss_code])),
        Int(row[:crossing_number]),
        Int(row[:writhe]),
        string(row[:gauss_hash]),
        jp,
        gen,
        sc,
        meta,
        DateTime(string(row[:created_at])),
        DateTime(string(row[:updated_at]))
    )
end

# -- Schema migration helpers --

function _get_schema_version(conn::SQLite.DB)::Int
    try
        for row in DBInterface.execute(conn, "SELECT value FROM schema_info WHERE key = 'version'")
            return parse(Int, string(row[:value]))
        end
    catch
    end
    return 1
end

function _migrate_v1_to_v2(conn::SQLite.DB)
    # Check if jones_polynomial column already exists
    has_jones = false
    for row in DBInterface.execute(conn, "PRAGMA table_info(knots)")
        if string(row[:name]) == "jones_polynomial"
            has_jones = true
            break
        end
    end

    if !has_jones
        for stmt in split(MIGRATE_V1_TO_V2, ";")
            stripped = strip(stmt)
            isempty(stripped) || DBInterface.execute(conn, stripped)
        end
    end
end

function _migrate_v2_to_v3(conn::SQLite.DB)
    existing_cols = Set{String}()
    for row in DBInterface.execute(conn, "PRAGMA table_info(knots)")
        push!(existing_cols, string(row[:name]))
    end

    if !("genus" in existing_cols)
        DBInterface.execute(conn, "ALTER TABLE knots ADD COLUMN genus INTEGER")
    end
    if !("seifert_circles" in existing_cols)
        DBInterface.execute(conn, "ALTER TABLE knots ADD COLUMN seifert_circles INTEGER")
    end
    DBInterface.execute(conn, "CREATE INDEX IF NOT EXISTS idx_knots_genus ON knots(genus)")
end
