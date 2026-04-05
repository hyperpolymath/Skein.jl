# SPDX-License-Identifier: MPL-2.0
# (PMPL-1.0-or-later preferred; MPL-2.0 required for Julia ecosystem)
# E2E pipeline tests for Skein.jl

using Test
using Skein

@testset "E2E Pipeline Tests" begin

    @testset "Full store-query-export pipeline" begin
        db = SkeinDB(":memory:")
        import_knotinfo!(db)
        @test Skein.count_knots(db) > 0

        # Query trefoil
        results = query(db, crossing_number=3)
        @test length(results) == 1
        @test results[1].name == "3_1"

        # Export CSV and verify content
        tmpfile = tempname() * ".csv"
        n = Skein.export_csv(db, tmpfile; crossing_number=3)
        @test n == 1
        content = read(tmpfile, String)
        @test occursin("3_1", content)
        rm(tmpfile)

        close(db)
    end

    @testset "Gauss code create → store → fetch → invariants pipeline" begin
        db = SkeinDB(":memory:")
        fig8 = GaussCode([1, -2, 3, -4, 2, -1, 4, -3])

        id = store!(db, "figure_eight", fig8; metadata=Dict("notation" => "4_1"))
        @test id isa String

        record = fetch_knot(db, "figure_eight")
        @test !isnothing(record)
        @test record.crossing_number == 4
        @test gauss_hash(record.gauss_code) == gauss_hash(fig8)

        close(db)
    end

    @testset "DT-to-Gauss → simplify → hash pipeline" begin
        # 4_1 figure-eight knot via DT notation
        g = dt_to_gauss([4, 8, 2, 6])
        @test crossing_number(g) == 4

        simplified = simplify(g)
        # Trefoil and figure-eight are already minimal
        @test crossing_number(simplified) <= 4
        @test gauss_hash(g) isa String
    end

    @testset "Error handling: duplicate store throws" begin
        db = SkeinDB(":memory:")
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        id1 = store!(db, "trefoil_dup", trefoil)
        @test id1 isa String
        @test_throws Exception store!(db, "trefoil_dup", trefoil)
        close(db)
    end

end
