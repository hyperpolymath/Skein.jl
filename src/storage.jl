# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
SQLite storage backend for Skein.jl

Schema is deliberately simple — one table for knots, one for metadata
key-value pairs. Invariants are stored as indexed columns for fast
filtering. Gauss code is retained for fallback ingestion, while PD-native
serialisation fields enable canonical storage of KnotTheory objects.
"""

const SCHEMA_VERSION = 4

const CREATE_TABLES = """
CREATE TABLE IF NOT EXISTS knots (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    gauss_code      TEXT NOT NULL,
    diagram_format  TEXT NOT NULL DEFAULT 'gauss',
    canonical_diagram TEXT,
    pd_code         TEXT,
    crossing_number INTEGER NOT NULL,
    writhe          INTEGER NOT NULL,
    gauss_hash      TEXT NOT NULL,
    alexander_polynomial TEXT,
    jones_polynomial TEXT,
    determinant     INTEGER,
    signature       INTEGER,
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
CREATE INDEX IF NOT EXISTS idx_knots_diagram_format ON knots(diagram_format);
CREATE INDEX IF NOT EXISTS idx_knots_alexander ON knots(alexander_polynomial);
CREATE INDEX IF NOT EXISTS idx_knots_jones ON knots(jones_polynomial);
CREATE INDEX IF NOT EXISTS idx_knots_determinant ON knots(determinant);
CREATE INDEX IF NOT EXISTS idx_knots_signature ON knots(signature);
CREATE INDEX IF NOT EXISTS idx_knots_genus ON knots(genus);
CREATE INDEX IF NOT EXISTS idx_knots_seifert ON knots(seifert_circles);
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
            if current_version < 4
                _migrate_v3_to_v4(conn)
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

_db_nullable(value) = value === nothing ? missing : value

function _string_or_nothing(value)
    if value === nothing || ismissing(value)
        return nothing
    end
    string(value)
end

function _int_or_nothing(value)
    if value === nothing || ismissing(value)
        return nothing
    end
    Int(value)
end

"""
    backfill_gauss_canonical!(db::SkeinDB) -> NamedTuple

Backfill legacy records that predate PD-aware schema fields:
- Ensures `diagram_format` is set to `"gauss"` when empty/null.
- Computes `canonical_diagram` for Gauss-backed rows when missing.

Returns `(diagram_format_updates = Int, canonical_diagram_updates = Int)`.
"""
function backfill_gauss_canonical!(db::SkeinDB)
    db.readonly && error("Database is read-only")

    touched_at = string(Dates.now())
    fmt_updates = 0
    canon_updates = 0

    fmt_rows = DBInterface.execute(db.conn,
        """SELECT id FROM knots
           WHERE diagram_format IS NULL OR TRIM(diagram_format) = ''""")
    for row in fmt_rows
        DBInterface.execute(db.conn,
            "UPDATE knots SET diagram_format = 'gauss', updated_at = ? WHERE id = ?",
            [touched_at, string(row[:id])])
        fmt_updates += 1
    end

    canon_rows = DBInterface.execute(db.conn,
        """SELECT id, gauss_code FROM knots
           WHERE diagram_format = 'gauss'
             AND (canonical_diagram IS NULL OR TRIM(canonical_diagram) = '')""")
    for row in canon_rows
        g = deserialise_gauss(string(row[:gauss_code]))
        canonical = serialise_gauss(canonical_gauss(g))
        DBInterface.execute(db.conn,
            "UPDATE knots SET canonical_diagram = ?, updated_at = ? WHERE id = ?",
            [canonical, touched_at, string(row[:id])])
        canon_updates += 1
    end

    (diagram_format_updates = fmt_updates, canonical_diagram_updates = canon_updates)
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

function _store_precomputed!(db::SkeinDB, name::String, g::GaussCode;
                             metadata::Dict{String, String} = Dict{String, String}(),
                             diagram_format::String = "gauss",
                             canonical_diagram::Union{String, Nothing} = nothing,
                             pd_code::Union{String, Nothing} = nothing,
                             crossing_number_value::Int = crossing_number(g),
                             writhe_value::Int = writhe(g),
                             gauss_hash_value::String = gauss_hash(g),
                             alexander_polynomial::Union{String, Nothing} = nothing,
                             jones_polynomial::Union{String, Nothing} = nothing,
                             determinant::Union{Int, Nothing} = nothing,
                             signature::Union{Int, Nothing} = nothing,
                             genus::Union{Int, Nothing} = nothing,
                             seifert_circle_count::Union{Int, Nothing} = nothing)
    db.readonly && error("Database is read-only")
    haskey(db, name) && error("Knot '$name' already exists")

    id = string(uuid4())
    code_str = serialise_gauss(g)
    now = string(Dates.now())

    DBInterface.execute(db.conn,
        """INSERT INTO knots (id, name, gauss_code, diagram_format, canonical_diagram, pd_code,
           crossing_number, writhe, gauss_hash, alexander_polynomial, jones_polynomial,
           determinant, signature, genus, seifert_circles, created_at, updated_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        [id, name, code_str, diagram_format, _db_nullable(canonical_diagram), _db_nullable(pd_code),
         crossing_number_value, writhe_value, gauss_hash_value,
         _db_nullable(alexander_polynomial), _db_nullable(jones_polynomial),
         _db_nullable(determinant), _db_nullable(signature), _db_nullable(genus),
         _db_nullable(seifert_circle_count), now, now])

    for (k, v) in metadata
        DBInterface.execute(db.conn,
            "INSERT INTO knot_metadata (knot_id, key, value) VALUES (?, ?, ?)",
            [id, k, v])
    end

    id
end

function store!(db::SkeinDB, name::String, g::GaussCode;
                metadata::Dict{String, String} = Dict{String, String}(),
                jones_polynomial::Union{String, Nothing} = nothing)
    cn = crossing_number(g)
    w = writhe(g)
    h = gauss_hash(g)

    # Auto-compute Jones polynomial if not provided and crossing count is manageable
    jp = jones_polynomial
    if jp === nothing && cn <= MAX_CROSSINGS_FOR_AUTO_JONES
        jp = jones_polynomial_str(g)
    end

    # Compute Seifert circles and genus
    sc = length(seifert_circles(g))
    gen = genus(g)
    canonical = serialise_gauss(canonical_gauss(g))

    _store_precomputed!(db, name, g;
                        metadata = metadata,
                        diagram_format = "gauss",
                        canonical_diagram = canonical,
                        pd_code = nothing,
                        crossing_number_value = cn,
                        writhe_value = w,
                        gauss_hash_value = h,
                        alexander_polynomial = nothing,
                        jones_polynomial = jp,
                        determinant = nothing,
                        signature = nothing,
                        genus = gen,
                        seifert_circle_count = sc)
end

"""
    fetch_knot(db::SkeinDB, name::String) -> Union{KnotRecord, Nothing}

Retrieve a knot by name. Returns `nothing` if not found.
"""
function fetch_knot(db::SkeinDB, name::String)::Union{KnotRecord, Nothing}
    result = DBInterface.execute(db.conn,
        "SELECT * FROM knots WHERE name = ?", [name])

    for row in result
        return row_to_record(db, row)
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
    diagram_format = string(row[:diagram_format])
    canonical_diagram = _string_or_nothing(row[:canonical_diagram])
    pd_code = _string_or_nothing(row[:pd_code])
    alex = _string_or_nothing(row[:alexander_polynomial])
    jp = _string_or_nothing(row[:jones_polynomial])
    det = _int_or_nothing(row[:determinant])
    sig = _int_or_nothing(row[:signature])
    gen = _int_or_nothing(row[:genus])
    sc = _int_or_nothing(row[:seifert_circles])
    KnotRecord(
        id,
        string(row[:name]),
        deserialise_gauss(string(row[:gauss_code])),
        diagram_format,
        canonical_diagram,
        pd_code,
        Int(row[:crossing_number]),
        Int(row[:writhe]),
        string(row[:gauss_hash]),
        alex,
        jp,
        det,
        sig,
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

function _migrate_v3_to_v4(conn::SQLite.DB)
    existing_cols = Set{String}()
    for row in DBInterface.execute(conn, "PRAGMA table_info(knots)")
        push!(existing_cols, string(row[:name]))
    end

    if !("diagram_format" in existing_cols)
        DBInterface.execute(conn, "ALTER TABLE knots ADD COLUMN diagram_format TEXT NOT NULL DEFAULT 'gauss'")
    end
    if !("canonical_diagram" in existing_cols)
        DBInterface.execute(conn, "ALTER TABLE knots ADD COLUMN canonical_diagram TEXT")
    end
    if !("pd_code" in existing_cols)
        DBInterface.execute(conn, "ALTER TABLE knots ADD COLUMN pd_code TEXT")
    end
    if !("alexander_polynomial" in existing_cols)
        DBInterface.execute(conn, "ALTER TABLE knots ADD COLUMN alexander_polynomial TEXT")
    end
    if !("determinant" in existing_cols)
        DBInterface.execute(conn, "ALTER TABLE knots ADD COLUMN determinant INTEGER")
    end
    if !("signature" in existing_cols)
        DBInterface.execute(conn, "ALTER TABLE knots ADD COLUMN signature INTEGER")
    end

    DBInterface.execute(conn, "CREATE INDEX IF NOT EXISTS idx_knots_diagram_format ON knots(diagram_format)")
    DBInterface.execute(conn, "CREATE INDEX IF NOT EXISTS idx_knots_alexander ON knots(alexander_polynomial)")
    DBInterface.execute(conn, "CREATE INDEX IF NOT EXISTS idx_knots_determinant ON knots(determinant)")
    DBInterface.execute(conn, "CREATE INDEX IF NOT EXISTS idx_knots_signature ON knots(signature)")
    DBInterface.execute(conn, "CREATE INDEX IF NOT EXISTS idx_knots_seifert ON knots(seifert_circles)")
end
