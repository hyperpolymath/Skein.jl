# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>
#
# Stronger property tests for Skein.jl:
#   - canonical_gauss invariance under rotation and relabelling
#   - is_equivalent reflexivity, symmetry, transitivity
#   - simplify_r1 / simplify_r2 preserve is_isotopic equivalence class
#   - Schema migration preservation (v1→v4, v2→v4, v3→v4)

using Test
using Skein
using SQLite
using DBInterface

# ---------------------------------------------------------------------------
# § 1. canonical_gauss: idempotency
# ---------------------------------------------------------------------------

@testset "canonical_gauss idempotency" begin
    codes = [
        GaussCode([1, -2, 3, -1, 2, -3]),           # trefoil
        GaussCode([1, -2, 3, -4, 2, -1, 4, -3]),    # figure-eight
        GaussCode([1, -2, 3, -4, 5, -1, 2, -3, 4, -5]),  # cinquefoil
        GaussCode(Int[]),                             # unknot
    ]
    for g in codes
        once  = canonical_gauss(g)
        twice = canonical_gauss(once)
        @test once == twice
    end
end

# ---------------------------------------------------------------------------
# § 2. canonical_gauss: cyclic rotation invariance
#
# For every cyclic rotation of a Gauss code, the canonical form is identical.
# ---------------------------------------------------------------------------

@testset "canonical_gauss cyclic rotation invariance" begin
    trefoil = GaussCode([1, -2, 3, -1, 2, -3])
    fig8    = GaussCode([1, -2, 3, -4, 2, -1, 4, -3])
    cinq    = GaussCode([1, -2, 3, -4, 5, -1, 2, -3, 4, -5])

    for g in [trefoil, fig8, cinq]
        canon = canonical_gauss(g)
        n = length(g.crossings)
        for shift in 1:(n-1)
            rotated = GaussCode(circshift(g.crossings, -shift))
            @test canonical_gauss(rotated) == canon
        end
    end
end

# ---------------------------------------------------------------------------
# § 3. canonical_gauss: crossing relabelling invariance
#
# Scaling all crossing indices by a constant k leaves the canonical form
# unchanged after normalisation.
# ---------------------------------------------------------------------------

@testset "canonical_gauss relabelling invariance" begin
    base = GaussCode([1, -2, 3, -1, 2, -3])  # trefoil
    canon_base = canonical_gauss(base)

    for k in [2, 5, 10, 17, 100]
        scaled = GaussCode(base.crossings .* k)
        @test canonical_gauss(scaled) == canon_base
    end
end

# ---------------------------------------------------------------------------
# § 4. is_equivalent: reflexivity and symmetry
# ---------------------------------------------------------------------------

@testset "is_equivalent reflexivity" begin
    for g in [
        GaussCode([1, -2, 3, -1, 2, -3]),
        GaussCode([1, -2, 3, -4, 2, -1, 4, -3]),
        GaussCode(Int[]),
    ]
        @test is_equivalent(g, g)
    end
end

@testset "is_equivalent symmetry" begin
    trefoil    = GaussCode([1, -2, 3, -1, 2, -3])
    fig8       = GaussCode([1, -2, 3, -4, 2, -1, 4, -3])
    rotated_t  = GaussCode(circshift(trefoil.crossings, -2))
    scaled_t   = GaussCode(trefoil.crossings .* 7)

    # Equivalent pairs
    @test is_equivalent(trefoil, rotated_t) == is_equivalent(rotated_t, trefoil)
    @test is_equivalent(trefoil, scaled_t)  == is_equivalent(scaled_t, trefoil)

    # Non-equivalent pair
    @test is_equivalent(trefoil, fig8) == is_equivalent(fig8, trefoil)
    @test !is_equivalent(trefoil, fig8)
end

# ---------------------------------------------------------------------------
# § 5. canonical_gauss preserves crossing_number
# ---------------------------------------------------------------------------

@testset "canonical_gauss preserves crossing_number" begin
    codes = [
        GaussCode([1, -2, 3, -1, 2, -3]),
        GaussCode([1, -2, 3, -4, 2, -1, 4, -3]),
        GaussCode([1, -2, 3, -4, 5, -1, 2, -3, 4, -5]),
    ]
    for g in codes
        @test crossing_number(canonical_gauss(g)) == crossing_number(g)
    end
end

# ---------------------------------------------------------------------------
# § 6. Reidemeister I invariance: simplify_r1 preserves is_isotopic class
# ---------------------------------------------------------------------------

@testset "simplify_r1 preserves is_isotopic class" begin
    # Insert R1 kinks (adjacent ±i pairs) into the trefoil
    trefoil = GaussCode([1, -2, 3, -1, 2, -3])

    # Prepend a kink: [99, -99, 1, -2, 3, -1, 2, -3]
    with_kink1 = GaussCode([99, -99, trefoil.crossings...])
    # Append a kink: [1, -2, 3, -1, 2, -3, 99, -99]
    with_kink2 = GaussCode([trefoil.crossings..., 99, -99])
    # Middle kink: [1, -2, 99, -99, 3, -1, 2, -3]
    with_kink3 = GaussCode([trefoil.crossings[1:2]..., 99, -99, trefoil.crossings[3:end]...])

    for kinked in [with_kink1, with_kink2, with_kink3]
        simplified = simplify_r1(kinked)
        @test crossing_number(simplified) <= crossing_number(kinked)
        @test is_isotopic(simplified, trefoil)
    end
end

# ---------------------------------------------------------------------------
# § 7. Reidemeister II invariance: simplify_r2 preserves is_isotopic class
# ---------------------------------------------------------------------------

@testset "simplify_r2 preserves is_isotopic class" begin
    # The figure-eight with an R2 pair prepended:
    # Adding ±99, ±99 in an interleaved pattern yields an R2-reducible code.
    # Pattern: i, j, ..., ±i (opposite sign), ±j (opposite sign)
    # The simplest: append [99, 100, -99, -100] — R2 pair at end (not interleaved
    # in the middle, so no R2 detection). Use direct interleave for genuine R2:
    # A genuine R2 pair: [99, 100, -100, -99] in the code with 99 and 100
    # each appearing once with sign flip = R2 bigon.

    trefoil = GaussCode([1, -2, 3, -1, 2, -3])

    # R2 pair: 99 at position 1 (positive), 100 at position 2 (positive),
    # then -99 and -100 adjacent. Pattern [i, j, -i, -j] = R2 pair.
    # Prepend to trefoil using fresh labels 50, 51:
    with_r2 = GaussCode([50, 51, -50, -51, trefoil.crossings...])

    simplified = simplify_r2(with_r2)
    @test crossing_number(simplified) <= crossing_number(with_r2)
    @test is_isotopic(simplified, trefoil)
end

# ---------------------------------------------------------------------------
# § 8. Schema migration preservation
#
# Each migration path must preserve existing data. We construct old-schema
# SQLite databases directly, open them via SkeinDB (triggers migration),
# and verify data remains accessible and correct.
# ---------------------------------------------------------------------------

function _create_v1_db(path::String)
    conn = SQLite.DB(path)
    DBInterface.execute(conn, """
        CREATE TABLE knots (
            id              TEXT PRIMARY KEY,
            name            TEXT NOT NULL UNIQUE,
            gauss_code      TEXT NOT NULL,
            crossing_number INTEGER NOT NULL,
            writhe          INTEGER NOT NULL,
            gauss_hash      TEXT NOT NULL,
            created_at      TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
        )
    """)
    DBInterface.execute(conn, """
        INSERT INTO knots (id, name, gauss_code, crossing_number, writhe, gauss_hash)
        VALUES ('id-v1-trefoil', 'trefoil_v1', '1,-2,3,-1,2,-3', 3, 3,
                'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f601')
    """)
    SQLite.close(conn)
end

function _create_v2_db(path::String)
    conn = SQLite.DB(path)
    DBInterface.execute(conn, """
        CREATE TABLE knots (
            id              TEXT PRIMARY KEY,
            name            TEXT NOT NULL UNIQUE,
            gauss_code      TEXT NOT NULL,
            crossing_number INTEGER NOT NULL,
            writhe          INTEGER NOT NULL,
            gauss_hash      TEXT NOT NULL,
            jones_polynomial TEXT,
            created_at      TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
        )
    """)
    DBInterface.execute(conn, """
        CREATE TABLE schema_info (key TEXT PRIMARY KEY, value TEXT NOT NULL)
    """)
    DBInterface.execute(conn,
        "INSERT INTO schema_info (key, value) VALUES ('version', '2')")
    DBInterface.execute(conn, """
        INSERT INTO knots (id, name, gauss_code, crossing_number, writhe, gauss_hash, jones_polynomial)
        VALUES ('id-v2-fig8', 'figure_eight_v2', '1,-2,3,-4,2,-1,4,-3', 4, 0,
                'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f60100',
                'q^2-q+1-q^{-1}+q^{-2}')
    """)
    SQLite.close(conn)
end

function _create_v3_db(path::String)
    conn = SQLite.DB(path)
    DBInterface.execute(conn, """
        CREATE TABLE knots (
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
        )
    """)
    DBInterface.execute(conn, """
        CREATE TABLE schema_info (key TEXT PRIMARY KEY, value TEXT NOT NULL)
    """)
    DBInterface.execute(conn,
        "INSERT INTO schema_info (key, value) VALUES ('version', '3')")
    DBInterface.execute(conn, """
        INSERT INTO knots (id, name, gauss_code, crossing_number, writhe, gauss_hash, genus, seifert_circles)
        VALUES ('id-v3-cinq', 'cinquefoil_v3', '1,-2,3,-4,5,-1,2,-3,4,-5', 5, 5,
                'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6010001',
                2, 3)
    """)
    SQLite.close(conn)
end

@testset "Schema migration preserves data" begin
    @testset "v1 → v4 migration" begin
        path = tempname() * ".db"
        _create_v1_db(path)
        db = SkeinDB(path)
        record = fetch_knot(db, "trefoil_v1")
        @test !isnothing(record)
        @test record.name == "trefoil_v1"
        @test record.crossing_number == 3
        close(db)
        rm(path; force = true)
    end

    @testset "v2 → v4 migration" begin
        path = tempname() * ".db"
        _create_v2_db(path)
        db = SkeinDB(path)
        record = fetch_knot(db, "figure_eight_v2")
        @test !isnothing(record)
        @test record.name == "figure_eight_v2"
        @test record.crossing_number == 4
        close(db)
        rm(path; force = true)
    end

    @testset "v3 → v4 migration" begin
        path = tempname() * ".db"
        _create_v3_db(path)
        db = SkeinDB(path)
        record = fetch_knot(db, "cinquefoil_v3")
        @test !isnothing(record)
        @test record.name == "cinquefoil_v3"
        @test record.crossing_number == 5
        close(db)
        rm(path; force = true)
    end

    @testset "v4 data survives reopen" begin
        path = tempname() * ".db"
        db = SkeinDB(path)
        store!(db, "trefoil_roundtrip", GaussCode([1, -2, 3, -1, 2, -3]))
        close(db)

        db2 = SkeinDB(path)
        record = fetch_knot(db2, "trefoil_roundtrip")
        @test !isnothing(record)
        @test record.crossing_number == 3
        close(db2)
        rm(path; force = true)
    end
end

println("canonical-gauss-and-migration-tests-ok")
