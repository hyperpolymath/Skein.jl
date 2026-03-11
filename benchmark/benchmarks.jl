# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

"""
Benchmarks for Skein.jl

Run with:
    julia --project=. benchmark/benchmarks.jl
"""

using Skein
using Random

Random.seed!(42)

# -- Helpers --

function random_gauss(n::Int)
    n == 0 && return GaussCode(Int[])
    entries = Int[]
    for i in 1:n
        push!(entries, i)
        push!(entries, -i)
    end
    GaussCode(entries[randperm(2n)])
end

function timed(label::String, f; warmup=3, trials=100)
    # Warmup
    for _ in 1:warmup
        f()
    end

    # Measure
    times = Float64[]
    for _ in 1:trials
        t = @elapsed f()
        push!(times, t)
    end

    median_t = sort(times)[div(length(times), 2) + 1]
    min_t = minimum(times)
    max_t = maximum(times)

    println("  $label: median=$(round(median_t * 1e6, digits=1))μs  min=$(round(min_t * 1e6, digits=1))μs  max=$(round(max_t * 1e6, digits=1))μs")
end

# -- Benchmarks --

println("=== Skein.jl Benchmarks ===\n")

# 1. Invariant computation
println("Invariant computation:")

trefoil = GaussCode([1, -2, 3, -1, 2, -3])
big_knot = random_gauss(50)

timed("crossing_number (3 crossings)", () -> crossing_number(trefoil))
timed("crossing_number (50 crossings)", () -> crossing_number(big_knot))
timed("writhe (3 crossings)", () -> writhe(trefoil))
timed("writhe (50 crossings)", () -> writhe(big_knot))
timed("gauss_hash (3 crossings)", () -> gauss_hash(trefoil))
timed("gauss_hash (50 crossings)", () -> gauss_hash(big_knot))
timed("normalise_gauss (3 crossings)", () -> Skein.normalise_gauss(trefoil))
timed("normalise_gauss (50 crossings)", () -> Skein.normalise_gauss(big_knot))

println()

# 2. Equivalence checking
println("Equivalence checking:")

rotated_trefoil = GaussCode([-2, 3, -1, 2, -3, 1])
small = random_gauss(5)
med = random_gauss(10)

timed("canonical_gauss (3 crossings)", () -> canonical_gauss(trefoil))
timed("canonical_gauss (5 crossings)", () -> canonical_gauss(small))
timed("canonical_gauss (10 crossings)", () -> canonical_gauss(med))
timed("is_equivalent (3 crossings)", () -> is_equivalent(trefoil, rotated_trefoil))
timed("mirror (3 crossings)", () -> mirror(trefoil))
timed("simplify_r1 (3 crossings)", () -> simplify_r1(trefoil))

println()

# 3. Database operations
println("Database operations:")

timed("SkeinDB open/close", () -> begin
    db = SkeinDB(":memory:")
    close(db)
end; trials=50)

db = SkeinDB(":memory:")
gc = GaussCode([1, -2, 3, -1, 2, -3])

timed("store! (single knot)", () -> begin
    name = "bench_$(rand(UInt64))"
    store!(db, name, gc)
end; trials=50)

# Populate for query benchmarks
for i in 1:100
    n = rand(0:8)
    store!(db, "qbench_$i", random_gauss(n))
end

timed("fetch_knot (by name)", () -> fetch_knot(db, "qbench_50"))
timed("query (crossing_number=3)", () -> query(db, crossing_number=3))
timed("query (crossing_number=0:4)", () -> query(db, crossing_number=0:4))
timed("query (composable predicate)", () -> query(db, crossing(3) | crossing(4)))
timed("haskey (existing)", () -> haskey(db, "qbench_1"))
timed("haskey (missing)", () -> haskey(db, "nonexistent_key"))
timed("count_knots", () -> Skein.count_knots(db))
timed("statistics", () -> Skein.statistics(db); trials=50)

println()

# 4. Bulk operations
println("Bulk operations:")

timed("bulk_import! (50 knots)", () -> begin
    bdb = SkeinDB(":memory:")
    knots = [("bulk_$i", random_gauss(rand(0:6))) for i in 1:50]
    bulk_import!(bdb, knots)
    close(bdb)
end; warmup=1, trials=20)

timed("import_knotinfo! (9 knots)", () -> begin
    bdb = SkeinDB(":memory:")
    Skein.import_knotinfo!(bdb)
    close(bdb)
end; warmup=1, trials=20)

println()

# 5. Export operations
println("Export operations:")

export_db = SkeinDB(":memory:")
for i in 1:50
    store!(export_db, "exp_$i", random_gauss(rand(0:6)))
end

tmpcsv = tempname() * ".csv"
tmpjson = tempname() * ".json"

timed("export_csv (50 knots)", () -> Skein.export_csv(export_db, tmpcsv); trials=20)
timed("export_json (50 knots)", () -> Skein.export_json(export_db, tmpjson); trials=20)

rm(tmpcsv; force=true)
rm(tmpjson; force=true)
close(export_db)

# 6. Find equivalents
println("\nEquivalence search:")

eq_db = SkeinDB(":memory:")
Skein.import_knotinfo!(eq_db)

timed("find_equivalents (in 9-knot DB)", () -> find_equivalents(eq_db, trefoil); trials=50)
timed("find_isotopic (in 9-knot DB)", () -> find_isotopic(eq_db, GaussCode([1, -1])); trials=50)

close(eq_db)
close(db)

println("\n=== Done ===")
