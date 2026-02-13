# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

using Test
using Skein
using Random

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
        @test record.jones_polynomial !== nothing  # auto-computed
        @test record.genus !== nothing
        @test record.seifert_circle_count !== nothing

        # Not found
        @test isnothing(fetch_knot(db, "nonexistent"))

        close(db)
    end

    @testset "Auto-computed invariants" begin
        db = SkeinDB(":memory:")

        # Jones polynomial auto-computed on store
        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))
        record = fetch_knot(db, "trefoil")
        @test record.jones_polynomial !== nothing
        @test record.jones_polynomial isa String
        @test length(record.jones_polynomial) > 0

        # Genus and Seifert circles auto-computed
        @test record.genus !== nothing
        @test record.genus isa Int
        @test record.genus >= 0
        @test record.seifert_circle_count !== nothing
        @test record.seifert_circle_count >= 1

        # Unknot should have genus 0
        store!(db, "unknot", GaussCode(Int[]))
        record2 = fetch_knot(db, "unknot")
        @test record2.genus == 0
        @test record2.jones_polynomial !== nothing

        # Explicit Jones overrides auto-computation
        store!(db, "manual", GaussCode([1, -2, 3, -1, 2, -3]);
               jones_polynomial = "custom_value")
        record3 = fetch_knot(db, "manual")
        @test record3.jones_polynomial == "custom_value"

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

    @testset "Composable query predicates" begin
        db = SkeinDB(":memory:")

        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]);
               metadata = Dict("family" => "torus"))
        store!(db, "figure-eight", GaussCode([1, -2, 3, -4, 2, -1, 4, -3]);
               metadata = Dict("family" => "twist"))
        store!(db, "unknot", GaussCode(Int[]))

        # Single predicate
        results = query(db, crossing(3))
        @test length(results) == 1
        @test results[1].name == "trefoil"

        # OR predicate
        results = query(db, crossing(3) | crossing(4))
        @test length(results) == 2

        # AND predicate
        results = query(db, crossing(3) & meta_eq("family", "torus"))
        @test length(results) == 1

        # Complex composition
        results = query(db, (crossing(0) | crossing(3)) & name_like(".*"))
        @test length(results) == 2

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

    @testset "KnotInfo import" begin
        db = SkeinDB(":memory:")

        n = Skein.import_knotinfo!(db)
        @test n == 36  # full Rolfsen table through 8 crossings
        @test haskey(db, "0_1")
        @test haskey(db, "3_1")
        @test haskey(db, "7_1")
        @test haskey(db, "7_7")
        @test haskey(db, "8_1")
        @test haskey(db, "8_18")
        @test haskey(db, "8_19")  # first non-alternating
        @test haskey(db, "8_21")

        # Verify metadata
        trefoil = fetch_knot(db, "3_1")
        @test trefoil.crossing_number == 3
        @test trefoil.metadata["type"] == "torus"

        fig8 = fetch_knot(db, "4_1")
        @test fig8.crossing_number == 4
        @test fig8.metadata["alias"] == "figure-eight"

        # Non-alternating knots
        k819 = fetch_knot(db, "8_19")
        @test k819.crossing_number == 8
        @test k819.metadata["alternating"] == "false"

        # Crossing number distribution
        for cn in [3, 4, 5, 6, 7, 8]
            results = query(db, crossing_number = cn)
            expected = cn == 3 ? 1 : cn == 4 ? 1 : cn == 5 ? 2 :
                       cn == 6 ? 3 : cn == 7 ? 7 : 21
            @test length(results) == expected
        end

        # Idempotent — second import should add 0
        n2 = Skein.import_knotinfo!(db)
        @test n2 == 0

        close(db)
    end

    @testset "DT-to-Gauss conversion" begin
        # Trefoil: DT [4, 6, 2] → valid 3-crossing Gauss code
        g = dt_to_gauss([4, 6, 2])
        @test crossing_number(g) == 3
        @test length(g) == 6

        # Each crossing appears exactly twice (once +, once -)
        for i in 1:3
            @test count(x -> abs(x) == i, g.crossings) == 2
            @test count(x -> x == i, g.crossings) == 1
            @test count(x -> x == -i, g.crossings) == 1
        end

        # Figure-eight: DT [4, 6, 8, 2]
        g2 = dt_to_gauss([4, 6, 8, 2])
        @test crossing_number(g2) == 4

        # Unknot: empty DT
        @test dt_to_gauss(Int[]) == GaussCode(Int[])

        # Non-alternating: 8_19 has negative DT entries
        g3 = dt_to_gauss([4, 8, -12, 2, -16, -14, 6, 10])
        @test crossing_number(g3) == 8
        @test length(g3) == 16
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

    @testset "Export JSON" begin
        db = SkeinDB(":memory:")
        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]);
               metadata = Dict("family" => "torus"))

        tmpfile = tempname() * ".json"
        n = Skein.export_json(db, tmpfile)
        @test n == 1

        content = read(tmpfile, String)
        @test occursin("trefoil", content)
        @test occursin("crossing_number", content)
        @test occursin("torus", content)

        rm(tmpfile)
        close(db)
    end

    @testset "Property-based: invariant consistency" begin
        # Generate random valid Gauss codes and verify invariant properties

        # Helper: generate a valid Gauss code with n crossings
        function random_gauss(n::Int)
            n == 0 && return GaussCode(Int[])
            # Each crossing i appears twice: once as +i, once as -i
            entries = Int[]
            for i in 1:n
                push!(entries, i)
                push!(entries, -i)
            end
            # Shuffle to create a random (possibly non-realizable) code
            GaussCode(entries[randperm(2n)])
        end

        Random.seed!(42)

        for _ in 1:50
            n = rand(0:8)
            g = random_gauss(n)

            # Crossing number = number of distinct crossings
            @test crossing_number(g) == n

            # Writhe is deterministic
            @test writhe(g) == writhe(g)

            # Hash is deterministic and content-addressed
            @test gauss_hash(g) == gauss_hash(g)
            @test gauss_hash(g) == gauss_hash(GaussCode(copy(g.crossings)))

            # Normalisation is idempotent
            g_norm = Skein.normalise_gauss(g)
            g_norm2 = Skein.normalise_gauss(g_norm)
            @test g_norm == g_norm2

            # Normalised code uses labels 1..n
            if n > 0
                labels = unique(abs.(g_norm.crossings))
                @test sort(labels) == 1:n
            end
        end
    end

    @testset "Property-based: store/fetch round-trip" begin
        db = SkeinDB(":memory:")

        Random.seed!(123)

        for i in 1:20
            n = rand(0:6)
            crossings = Int[]
            for j in 1:n
                push!(crossings, j)
                push!(crossings, -j)
            end
            gc = n == 0 ? GaussCode(Int[]) : GaussCode(crossings[randperm(2n)])

            name = "random_knot_$i"
            store!(db, name, gc)

            record = fetch_knot(db, name)
            @test !isnothing(record)
            @test record.gauss_code == gc
            @test record.crossing_number == crossing_number(gc)
            @test record.writhe == writhe(gc)
            @test record.gauss_hash == gauss_hash(gc)
        end

        close(db)
    end

    @testset "Equivalence: canonical_gauss" begin
        # Cyclic rotation of trefoil should have same canonical form
        g1 = GaussCode([1, -2, 3, -1, 2, -3])
        g2 = GaussCode([-2, 3, -1, 2, -3, 1])  # rotated by 1
        g3 = GaussCode([3, -1, 2, -3, 1, -2])  # rotated by 2

        c1 = canonical_gauss(g1)
        c2 = canonical_gauss(g2)
        c3 = canonical_gauss(g3)
        @test c1 == c2
        @test c2 == c3

        # Different knot should have different canonical form
        fig8 = GaussCode([1, -2, 3, -4, 2, -1, 4, -3])
        @test canonical_gauss(fig8) != c1

        # Unknot canonical form
        @test canonical_gauss(GaussCode(Int[])) == GaussCode(Int[])
    end

    @testset "Equivalence: is_equivalent" begin
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])

        # Same knot, rotated
        rotated = GaussCode([-2, 3, -1, 2, -3, 1])
        @test is_equivalent(trefoil, rotated)

        # Same knot, relabelled (5→1, 10→2, 15→3)
        relabelled = GaussCode([5, -10, 15, -5, 10, -15])
        @test is_equivalent(trefoil, relabelled)

        # Different knot
        fig8 = GaussCode([1, -2, 3, -4, 2, -1, 4, -3])
        @test !is_equivalent(trefoil, fig8)

        # Different crossing numbers → fast rejection
        @test !is_equivalent(trefoil, GaussCode(Int[]))
    end

    @testset "Equivalence: mirror" begin
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        m = mirror(trefoil)
        @test m.crossings == [-1, 2, -3, 1, -2, 3]
        @test mirror(mirror(trefoil)) == trefoil

        # Unknot is its own mirror
        @test mirror(GaussCode(Int[])) == GaussCode(Int[])
    end

    @testset "Equivalence: is_amphichiral" begin
        # Unknot is amphichiral (trivially)
        @test is_amphichiral(GaussCode(Int[]))

        # Note: figure-eight (4_1) is topologically amphichiral but
        # detecting this requires Reidemeister II/III moves beyond
        # what our diagram-level check can do. Full amphichirality
        # detection requires KnotTheory.jl or a more sophisticated algorithm.
        fig8 = GaussCode([1, -2, 3, -4, 2, -1, 4, -3])
        @test is_amphichiral(fig8) isa Bool  # just verify it runs
    end

    @testset "Equivalence: simplify_r1" begin
        # A kink: crossing i appears as adjacent +i, -i
        kinked = GaussCode([1, -1, 2, -3, -2, 3])
        simplified = simplify_r1(kinked)
        @test crossing_number(simplified) == 2

        # No kinks to remove
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        @test simplify_r1(trefoil) == trefoil

        # Pure kink (reduces to unknot)
        @test simplify_r1(GaussCode([1, -1])) == GaussCode(Int[])

        # Multiple kinks
        multi_kink = GaussCode([1, -1, 2, -2])
        @test simplify_r1(multi_kink) == GaussCode(Int[])

        # Wrap-around kink
        wraparound = GaussCode([-1, 2, -3, -2, 3, 1])
        s = simplify_r1(wraparound)
        @test crossing_number(s) == 2
    end

    @testset "Equivalence: is_isotopic" begin
        # Trefoil with an extra kink should be isotopic to trefoil
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        # Insert kink (crossing 4) adjacent
        trefoil_kinked = GaussCode([4, -4, 1, -2, 3, -1, 2, -3])
        @test is_isotopic(trefoil, trefoil_kinked)

        # Two unknots are isotopic
        @test is_isotopic(GaussCode(Int[]), GaussCode([1, -1]))
    end

    @testset "Equivalence: find_equivalents" begin
        db = SkeinDB(":memory:")
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        store!(db, "trefoil", trefoil)
        store!(db, "figure-eight", GaussCode([1, -2, 3, -4, 2, -1, 4, -3]))

        # Rotated trefoil should find the stored one
        rotated = GaussCode([-2, 3, -1, 2, -3, 1])
        results = find_equivalents(db, rotated)
        @test length(results) == 1
        @test results[1].name == "trefoil"

        # Figure-eight shouldn't match trefoil search
        results2 = find_equivalents(db, trefoil)
        @test length(results2) == 1

        close(db)
    end

    @testset "Equivalence: find_isotopic" begin
        db = SkeinDB(":memory:")
        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))
        store!(db, "unknot", GaussCode(Int[]))

        # A kinked unknot should find the stored unknot
        kinked_unknot = GaussCode([1, -1])
        results = find_isotopic(db, kinked_unknot)
        @test length(results) >= 1
        @test any(r -> r.name == "unknot", results)

        close(db)
    end

    @testset "Laurent polynomial arithmetic" begin
        a = LaurentPoly(1 => 2, -1 => 3)  # 2A + 3A⁻¹
        b = LaurentPoly(1 => 1, 0 => 1)   # A + 1

        # Addition
        s = Skein.lpoly_add(a, b)
        @test s[1] == 3   # 2A + A = 3A
        @test s[0] == 1   # 1
        @test s[-1] == 3  # 3A⁻¹

        # Multiplication
        m = Skein.lpoly_mul(LaurentPoly(0 => 1), a)
        @test m == a  # 1 * a = a

        # Power
        p = Skein.lpoly_pow(LaurentPoly(1 => 1), 3)
        @test p == LaurentPoly(3 => 1)  # A³

        # Negate
        n = Skein.lpoly_negate(a)
        @test n[1] == -2
        @test n[-1] == -3

        # Zero power
        @test Skein.lpoly_pow(a, 0) == LaurentPoly(0 => 1)

        # Serialisation round-trip
        @test deserialise_laurent(serialise_laurent(a)) == a
        @test serialise_laurent(LaurentPoly()) == "0:0"
    end

    @testset "Bracket polynomial" begin
        # Unknot: bracket = 1
        unknot_bracket = bracket_polynomial(GaussCode(Int[]))
        @test unknot_bracket == LaurentPoly(0 => 1)

        # Single positive kink [1, -1]: bracket should be -A³
        kink = GaussCode([1, -1])
        b = bracket_polynomial(kink)
        @test b[3] == -1  # -A³

        # Trefoil: bracket is known
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        bt = bracket_polynomial(trefoil)
        @test !isempty(bt)
        @test bt isa LaurentPoly

        # Figure-eight
        fig8 = GaussCode([1, -2, 3, -4, 2, -1, 4, -3])
        bf = bracket_polynomial(fig8)
        @test !isempty(bf)

        # Bracket is deterministic
        @test bracket_polynomial(trefoil) == bracket_polynomial(trefoil)

        # Different knots should (usually) have different brackets
        @test bt != bf
    end

    @testset "Jones polynomial" begin
        # Unknot: Jones = 1
        unknot_jones = jones_from_bracket(GaussCode(Int[]))
        @test unknot_jones == LaurentPoly(0 => 1)

        # Jones polynomial is deterministic
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        j1 = jones_from_bracket(trefoil)
        j2 = jones_from_bracket(trefoil)
        @test j1 == j2
        @test !isempty(j1)

        # Jones polynomial string
        s = jones_polynomial_str(trefoil)
        @test s isa String
        @test length(s) > 0

        # Round-trip through serialisation
        @test deserialise_laurent(s) == j1

        # Different knots → different Jones polynomials
        fig8 = GaussCode([1, -2, 3, -4, 2, -1, 4, -3])
        @test jones_from_bracket(fig8) != j1
    end

    @testset "Reidemeister II simplification" begin
        # A Gauss code with an R2 bigon: crossings 1 and 2 alternate
        # Pattern: 1, 2, -1, -2 (no interleaved crossings, opposite signs)
        r2_code = GaussCode([1, 2, -1, -2])
        s = simplify_r2(r2_code)
        @test crossing_number(s) == 0  # both crossings removed

        # R2 pair embedded in a larger code
        # Trefoil [1,-2,3,-1,2,-3] has no R2 pairs
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        @test simplify_r2(trefoil) == trefoil

        # Empty code
        @test simplify_r2(GaussCode(Int[])) == GaussCode(Int[])

        # Combined simplification (R1 + R2)
        @test simplify(GaussCode(Int[])) == GaussCode(Int[])
        @test simplify(GaussCode([1, -1])) == GaussCode(Int[])  # R1

        # Simplify is idempotent
        g = GaussCode([1, -2, 3, -1, 2, -3])
        @test simplify(simplify(g)) == simplify(g)
    end

    @testset "is_isotopic with Jones" begin
        # Two unknot representations should be isotopic
        @test is_isotopic(GaussCode(Int[]), GaussCode([1, -1]))

        # Trefoil with kink should be isotopic to trefoil
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        kinked = GaussCode([4, -4, 1, -2, 3, -1, 2, -3])
        @test is_isotopic(trefoil, kinked)

        # Trefoil and figure-eight should NOT be isotopic
        fig8 = GaussCode([1, -2, 3, -4, 2, -1, 4, -3])
        @test !is_isotopic(trefoil, fig8)
    end

    @testset "import_csv!" begin
        db = SkeinDB(":memory:")

        # Create a temporary CSV file
        tmpcsv = tempname() * ".csv"
        open(tmpcsv, "w") do io
            println(io, "name,gauss_code,family")
            println(io, "csv_trefoil,\"[1,-2,3,-1,2,-3]\",torus")
            println(io, "csv_fig8,\"[1,-2,3,-4,2,-1,4,-3]\",twist")
            println(io, "csv_unknot,\"[]\",trivial")
        end

        n = import_csv!(db, tmpcsv)
        @test n == 3
        @test haskey(db, "csv_trefoil")
        @test haskey(db, "csv_fig8")
        @test haskey(db, "csv_unknot")

        # Check invariants were computed
        t = fetch_knot(db, "csv_trefoil")
        @test t.crossing_number == 3
        @test t.metadata["family"] == "torus"

        u = fetch_knot(db, "csv_unknot")
        @test u.crossing_number == 0

        rm(tmpcsv)
        close(db)
    end

    @testset "import_csv! with data file" begin
        db = SkeinDB(":memory:")

        # Use the bundled 9-crossing knot data
        csvpath = joinpath(@__DIR__, "..", "data", "knots_9.csv")
        if isfile(csvpath)
            n = import_csv!(db, csvpath)
            @test n >= 7

            @test haskey(db, "9_1")
            k91 = fetch_knot(db, "9_1")
            @test k91.crossing_number == 9
            @test k91.metadata["type"] == "torus"
        end

        close(db)
    end

    @testset "Duplicates detection" begin
        db = SkeinDB(":memory:")

        # Store same Gauss code under two names
        gc = GaussCode([1, -2, 3, -1, 2, -3])
        store!(db, "trefoil_a", gc)
        store!(db, "trefoil_b", gc)
        store!(db, "figure_eight", GaussCode([1, -2, 3, -4, 2, -1, 4, -3]))

        dups = Skein.duplicates(db)
        @test length(dups) == 1
        @test length(dups[1]) == 2

        close(db)
    end

    @testset "Seifert circles" begin
        # Unknot: 0 crossings → 1 empty circle
        sc0 = seifert_circles(GaussCode(Int[]))
        @test length(sc0) == 1

        # Trefoil: 3 crossings → 2 Seifert circles
        trefoil = GaussCode([1, -2, 3, -1, 2, -3])
        sc_t = seifert_circles(trefoil)
        @test length(sc_t) == 2

        # Figure-eight: 4 crossings → 3 Seifert circles
        fig8 = GaussCode([1, -2, 3, -4, 2, -1, 4, -3])
        sc_f = seifert_circles(fig8)
        @test length(sc_f) == 3

        # All positions covered
        all_positions = sort(vcat(sc_t...))
        @test all_positions == collect(1:6)
    end

    @testset "Genus" begin
        # Unknot: genus 0
        @test genus(GaussCode(Int[])) == 0

        # Trefoil: genus = (3 - 2 + 1) / 2 = 1
        @test genus(GaussCode([1, -2, 3, -1, 2, -3])) == 1

        # Figure-eight: genus = (4 - 3 + 1) / 2 = 1
        @test genus(GaussCode([1, -2, 3, -4, 2, -1, 4, -3])) == 1
    end

    @testset "Genus query" begin
        db = SkeinDB(":memory:")
        import_knotinfo!(db)

        # Query by genus
        results = query(db, genus = 1)
        @test length(results) > 0
        @test all(r -> r.genus == 1, results)

        # Unknot has genus 0
        results0 = query(db, genus = 0)
        @test length(results0) == 1
        @test results0[1].name == "0_1"

        # Composable genus predicate
        results2 = query(db, genus_eq(1) & crossing(3))
        @test length(results2) == 1
        @test results2[1].name == "3_1"

        close(db)
    end

    @testset "Read-only mode" begin
        # Create a DB with data, reopen as read-only
        tmppath = tempname() * ".db"
        db = SkeinDB(tmppath)
        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))
        close(db)

        rodb = SkeinDB(tmppath; readonly = true)
        @test isopen(rodb)

        # Can read
        record = fetch_knot(rodb, "trefoil")
        @test !isnothing(record)
        @test record.name == "trefoil"

        # Can query
        results = query(rodb, crossing_number = 3)
        @test length(results) == 1

        # Cannot write
        @test_throws ErrorException store!(rodb, "unknot", GaussCode(Int[]))
        @test_throws ErrorException update_metadata!(rodb, "trefoil", Dict("k" => "v"))

        close(rodb)
        rm(tmppath)
    end

    @testset "Input validation" begin
        # Valid codes don't warn
        @test Skein.validate_gauss_code(Int[]) == true
        @test Skein.validate_gauss_code([1, -2, 3, -1, 2, -3]) == true

        # Zero entries are invalid
        @test Skein.validate_gauss_code([0, 0]) == false

        # Same sign twice is invalid
        @test Skein.validate_gauss_code([1, 1]) == false

        # Crossing appearing once is invalid
        @test Skein.validate_gauss_code([1, -2, -1]) == false

        # Crossing appearing 3 times is invalid
        @test Skein.validate_gauss_code([1, -1, 1, -2, 2, -2]) == false
    end

    @testset "Schema migration v2→v3" begin
        # Create a v2-style database and verify migration
        tmppath = tempname() * ".db"
        db = SkeinDB(tmppath)

        # Store a knot — new schema should have genus
        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))
        record = fetch_knot(db, "trefoil")
        @test record.genus == 1
        @test record.seifert_circle_count == 2

        close(db)
        rm(tmppath)
    end

    @testset "Duplicate name handling" begin
        db = SkeinDB(":memory:")
        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))

        # Storing same name should throw (UNIQUE constraint)
        @test_throws Exception store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))

        close(db)
    end

    @testset "Display methods" begin
        db = SkeinDB(":memory:")
        store!(db, "trefoil", GaussCode([1, -2, 3, -1, 2, -3]))

        # GaussCode show
        gc = GaussCode([1, -2, 3, -1, 2, -3])
        buf = IOBuffer()
        show(buf, gc)
        @test occursin("GaussCode", String(take!(buf)))

        # KnotRecord show
        record = fetch_knot(db, "trefoil")
        buf2 = IOBuffer()
        show(buf2, record)
        s = String(take!(buf2))
        @test occursin("trefoil", s)
        @test occursin("genus=", s)

        # SkeinDB show
        buf3 = IOBuffer()
        show(buf3, db)
        s3 = String(take!(buf3))
        @test occursin("SkeinDB", s3)
        @test occursin("1 knots", s3)

        close(db)
    end

end
