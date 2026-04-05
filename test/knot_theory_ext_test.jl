# SPDX-License-Identifier: PMPL-1.0-or-later

using Test
using Skein
using KnotTheory

@testset "KnotTheory extension integration" begin
    @testset "PlanarDiagram storage caches KnotTheory invariants" begin
        db = SkeinDB(":memory:")
        pd = trefoil().pd

        id = store!(db, "kt_trefoil_pd", pd)
        @test id isa String

        record = fetch_knot(db, "kt_trefoil_pd")
        @test !isnothing(record)
        @test record.diagram_format == "pd"
        @test !isnothing(record.pd_code)
        @test !isnothing(record.canonical_diagram)
        @test !isnothing(record.alexander_polynomial)
        @test !isnothing(record.jones_polynomial)
        @test record.crossing_number == length(pd.crossings)
        @test record.writhe == sum(c.sign for c in pd.crossings)
        @test record.determinant == KnotTheory.determinant(pd)
        @test record.signature == KnotTheory.signature(pd)

        # Indexed invariant filters should resolve this record quickly.
        @test length(query(db, determinant = record.determinant)) >= 1
        @test length(query(db, signature = record.signature)) >= 1
        @test length(query(db, alexander_polynomial = record.alexander_polynomial)) >= 1
        @test length(query(db, jones_polynomial = record.jones_polynomial)) >= 1
        @test length(query(db, diagram_format = "pd")) == 1

        close(db)
    end

    @testset "Round-trip PlanarDiagram and Knot through Skein" begin
        db = SkeinDB(":memory:")

        k = figure_eight()
        store!(db, "kt_fig8", k)
        record = fetch_knot(db, "kt_fig8")
        @test !isnothing(record)

        pd2 = to_planardiagram(record)
        k2 = to_knot(record)

        @test length(pd2.crossings) == length(k.pd.crossings)
        @test KnotTheory.determinant(pd2) == KnotTheory.determinant(k.pd)
        @test KnotTheory.signature(pd2) == KnotTheory.signature(k.pd)
        @test KnotTheory.crossing_number(k2) == KnotTheory.crossing_number(k)
        @test KnotTheory.writhe(k2) == KnotTheory.writhe(k)

        close(db)
    end

    @testset "Gauss fallback remains available" begin
        db = SkeinDB(":memory:")
        g = GaussCode([1, -2, 3, -1, 2, -3])
        store!(db, "gauss_trefoil", g)
        record = fetch_knot(db, "gauss_trefoil")
        @test !isnothing(record)
        @test record.diagram_format == "gauss"
        @test isnothing(record.pd_code)
        @test isnothing(record.alexander_polynomial)
        close(db)
    end
end
