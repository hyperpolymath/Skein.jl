# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

using Test
using Skein

@testset "Skein.jl" begin

    @testset "GaussCode" begin
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        @test length(trefoil) == 6

        unknot = GaussCode(Int[])
        @test length(unknot) == 0

        @test trefoil == GaussCode([1, -2, 3, -1, 2, -3])
        @test trefoil != unknot
    end

    @testset "Invariants" begin
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        figure_eight = GaussCode([1, -2, 3, -4, 2, -1, 4, -3])
        unknot = GaussCode(Int[])

        @test crossing_number(trefoil) == 3
        @test crossing_number(figure_eight) == 4
        @test crossing_number(unknot) == 0

        @test writhe(unknot) == 0
        @test writhe(trefoil) isa Int
        @test writhe(figure_eight) isa Int

        @test gauss_hash(trefoil) isa String
        @test length(gauss_hash(trefoil)) == 64  # SHA-256 hex
        @test gauss_hash(trefoil) == gauss_hash(GaussCode([1, -2, 3, -1, 2, -3]))
        @test gauss_hash(trefoil) != gauss_hash(figure_eight)
    end

    @testset "Normalisation" begin
        # Relabelled trefoil should normalise to same form
        g1 = GaussCode([5, -10, 15, -5, 10, -15])
        g2 = Skein.normalise_gauss(g1)
        @test g2.crossings == [1, -2, 3, -1, 2, -3]
    end

    @testset "Database lifecycle" begin
        db = SkeinDB(":memory:")
        @test isopen(db)
        @test Skein.count_knots(db) == 0

        close(db)
        @test !isopen(db)
    end

    @testset "Store and fetch" begin
        db = SkeinDB(":memory:")

        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        id = store!(db, "trefoil", trefoil;
                    metadata = Dict("family" => "torus", "notation" => "3_1"))

        @test id isa String
        @test Skein.count_knots(db) == 1

        record = fetch_knot(db, "trefoil")
        @test !isnothing(record)
        @test record.name == "trefoil"
        @test record.crossing_number == 3
        @test record.gauss_code == trefoil
        @test record.metadata["family"] == "torus"
        @test record.metadata["notation"] == "3_1"

        # Not found
        @test isnothing(fetch_knot(db, "nonexistent"))

        close(db)
    end

    @testset "Query" begin
        db = SkeinDB(":memory:")

        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]);
               metadata = Dict("family" => "torus"))
        store!(db, "figure-eight", GaussCode([1, -2, 3, -4, 2, -1, 4, -3]);
               metadata = Dict("family" => "twist"))
        store!(db, "unknot", GaussCode(Int[]))

        # Exact crossing number
        results = query(db, crossing_number = 3)
        @test length(results) == 1
        @test results[1].name == "trefoil"

        # Range query
        results = query(db, crossing_number = 3:4)
        @test length(results) == 2

        # Zero crossings
        results = query(db, crossing_number = 0)
        @test length(results) == 1
        @test results[1].name == "unknot"

        # Metadata query
        results = query(db, meta = ("family" => "torus"))
        @test length(results) == 1
        @test results[1].name == "trefoil"

        # Name pattern
        results = query(db, name_like = "%eight%")
        @test length(results) == 1

        close(db)
    end

    @testset "haskey" begin
        db = SkeinDB(":memory:")
        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))

        @test haskey(db, "trefoil")
        @test !haskey(db, "nonexistent")

        close(db)
    end

    @testset "Delete" begin
        db = SkeinDB(":memory:")
        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))

        @test Skein.count_knots(db) == 1
        Skein.delete!(db, "trefoil")
        @test Skein.count_knots(db) == 0

        close(db)
    end

    @testset "Update metadata" begin
        db = SkeinDB(":memory:")
        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))

        update_metadata!(db, "trefoil", Dict("source" => "manual", "verified" => "true"))

        record = fetch_knot(db, "trefoil")
        @test record.metadata["source"] == "manual"
        @test record.metadata["verified"] == "true"

        close(db)
    end

    @testset "Bulk import" begin
        db = SkeinDB(":memory:")

        knots = [
            ("3_1", GaussCode([1, -2, 3, -1, 2, -3])),
            ("4_1", GaussCode([1, -2, 3, -4, 2, -1, 4, -3])),
        ]

        bulk_import!(db, knots)
        @test Skein.count_knots(db) == 2

        close(db)
    end

    @testset "Statistics" begin
        db = SkeinDB(":memory:")
        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))
        store!(db, "figure-eight", GaussCode([1, -2, 3, -4, 2, -1, 4, -3]))

        stats = Skein.statistics(db)
        @test stats.total_knots == 2
        @test stats.min_crossings == 3
        @test stats.max_crossings == 4
        @test stats.crossing_distribution[3] == 1
        @test stats.crossing_distribution[4] == 1

        close(db)
    end

    @testset "Export CSV" begin
        db = SkeinDB(":memory:")
        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))

        tmpfile = tempname() * ".csv"
        n = Skein.export_csv(db, tmpfile)
        @test n == 1
        @test isfile(tmpfile)

        content = read(tmpfile, String)
        @test occursin("trefoil", content)
        @test occursin("crossing_number", content)

        rm(tmpfile)
        close(db)
    end

end
