-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Schema for Skein.jl FFI (must match src/storage.jl SCHEMA_VERSION 2)

CREATE TABLE IF NOT EXISTS knots (
    id              TEXT PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    gauss_code      TEXT NOT NULL,
    crossing_number INTEGER NOT NULL,
    writhe          INTEGER NOT NULL,
    gauss_hash      TEXT NOT NULL,
    jones_polynomial TEXT,
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
CREATE INDEX IF NOT EXISTS idx_metadata_key ON knot_metadata(key);

INSERT OR REPLACE INTO schema_info (key, value) VALUES ('version', '2');
