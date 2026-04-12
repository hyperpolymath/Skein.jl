# SPDX-License-Identifier: PMPL-1.0-or-later
# (MPL-2.0 is automatic legal fallback until PMPL is formally recognised)
# Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#
# Skein.jl — Benchmark suite with Six Sigma classification.
#
# Run:
#   julia --project=. benchmark/benchmarks.jl
#
# Six Sigma tiers (relative to BASELINES below):
#   UNACCEPTABLE  : >50 % regression  — hard fail
#   ACCEPTABLE    : 20–50 % regression — soft fail
#   ORDINARY      : ±20 %             — pass
#   EXTRAORDINARY : >20 % improvement — pass + flag
#
# First run: all BASELINES entries are 0.0.  The script prints "[BASELINE]"
# lines with measured μs values.  Copy those into BASELINES for CI runs.

using Skein
using Random
using Dates
using Printf

Random.seed!(42)

# ── Six Sigma baselines (microseconds) ────────────────────────────────────────
# Populate from a "[BASELINE]" run.  Leave 0.0 to treat a key as unset.
const BASELINES = Dict{String, Float64}(
    # invariant computation
    "crossing_number (3 crossings)"   => 0.0,
    "crossing_number (50 crossings)"  => 0.0,
    "writhe (3 crossings)"            => 0.0,
    "writhe (50 crossings)"           => 0.0,
    "gauss_hash (3 crossings)"        => 0.0,
    "gauss_hash (50 crossings)"       => 0.0,
    "normalise_gauss (3 crossings)"   => 0.0,
    "normalise_gauss (50 crossings)"  => 0.0,
    # equivalence checking
    "canonical_gauss (3 crossings)"   => 0.0,
    "canonical_gauss (5 crossings)"   => 0.0,
    "canonical_gauss (10 crossings)"  => 0.0,
    "is_equivalent (3 crossings)"     => 0.0,
    "mirror (3 crossings)"            => 0.0,
    "simplify_r1 (3 crossings)"       => 0.0,
    # database ops
    "SkeinDB open/close"              => 0.0,
    "store! (single knot)"            => 0.0,
    "fetch_knot (by name)"            => 0.0,
    "query (crossing_number=3)"       => 0.0,
    "query (crossing_number=0:4)"     => 0.0,
    "query (composable predicate)"    => 0.0,
    "haskey (existing)"               => 0.0,
    "haskey (missing)"                => 0.0,
    "count_knots"                     => 0.0,
    "statistics"                      => 0.0,
    # bulk ops
    "bulk_import! (50 knots)"         => 0.0,
    "import_knotinfo! (9 knots)"      => 0.0,
    # export
    "export_csv (50 knots)"           => 0.0,
    "export_json (50 knots)"          => 0.0,
    # equivalence search
    "find_equivalents (in 9-knot DB)" => 0.0,
    "find_isotopic (in 9-knot DB)"    => 0.0,
)

# ── Six Sigma classifier ───────────────────────────────────────────────────────
const _SIGMA_COUNTS = Dict(:baseline => 0, :extraordinary => 0,
                            :ordinary => 0, :acceptable => 0, :unacceptable => 0)

function classify_sigma(label::String, measured_us::Float64)::Symbol
    baseline = get(BASELINES, label, 0.0)
    if baseline == 0.0
        @printf("  [BASELINE]      %-40s  %.1f μs\n", label, measured_us)
        _SIGMA_COUNTS[:baseline] += 1
        return :baseline
    end
    pct = (measured_us - baseline) / baseline * 100.0
    if pct > 50.0
        @printf("  [UNACCEPTABLE]  %-40s  %+.1f %%  HARD FAIL\n", label, pct)
        _SIGMA_COUNTS[:unacceptable] += 1
        return :unacceptable
    elseif pct > 20.0
        @printf("  [ACCEPTABLE]    %-40s  %+.1f %%  soft fail\n", label, pct)
        _SIGMA_COUNTS[:acceptable] += 1
        return :acceptable
    elseif pct >= -20.0
        @printf("  [ORDINARY]      %-40s  %+.1f %%\n", label, pct)
        _SIGMA_COUNTS[:ordinary] += 1
        return :ordinary
    else
        @printf("  [EXTRAORDINARY] %-40s  %+.1f %%  improvement\n", label, pct)
        _SIGMA_COUNTS[:extraordinary] += 1
        return :extraordinary
    end
end

# ── Timing helper ──────────────────────────────────────────────────────────────
function timed_us(f; warmup=3, trials=100)::Float64
    for _ in 1:warmup; f(); end
    times = Vector{Float64}(undef, trials)
    for i in 1:trials; times[i] = @elapsed f(); end
    sort!(times)
    times[div(trials, 2) + 1] * 1e6   # median in μs
end

# ── Helpers ────────────────────────────────────────────────────────────────────
function random_gauss(n::Int)
    n == 0 && return GaussCode(Int[])
    entries = Int[]
    for i in 1:n
        push!(entries, i)
        push!(entries, -i)
    end
    GaussCode(entries[randperm(2n)])
end

# ── Header ─────────────────────────────────────────────────────────────────────
println("=== Skein.jl Benchmarks (Six Sigma) ===")
println("Date: $(today())\n")

# ── 1. Invariant computation ───────────────────────────────────────────────────
println("─── Invariant computation ─────────────────────────────────────────────")

trefoil  = GaussCode([1, -2, 3, -1, 2, -3])
big_knot = random_gauss(50)

classify_sigma("crossing_number (3 crossings)",  timed_us(() -> crossing_number(trefoil)))
classify_sigma("crossing_number (50 crossings)", timed_us(() -> crossing_number(big_knot)))
classify_sigma("writhe (3 crossings)",           timed_us(() -> writhe(trefoil)))
classify_sigma("writhe (50 crossings)",          timed_us(() -> writhe(big_knot)))
classify_sigma("gauss_hash (3 crossings)",       timed_us(() -> gauss_hash(trefoil)))
classify_sigma("gauss_hash (50 crossings)",      timed_us(() -> gauss_hash(big_knot)))
classify_sigma("normalise_gauss (3 crossings)",  timed_us(() -> Skein.normalise_gauss(trefoil)))
classify_sigma("normalise_gauss (50 crossings)", timed_us(() -> Skein.normalise_gauss(big_knot)))

println()

# ── 2. Equivalence checking ────────────────────────────────────────────────────
println("─── Equivalence checking ──────────────────────────────────────────────")

rotated = GaussCode([-2, 3, -1, 2, -3, 1])
small   = random_gauss(5)
med     = random_gauss(10)

classify_sigma("canonical_gauss (3 crossings)",  timed_us(() -> canonical_gauss(trefoil)))
classify_sigma("canonical_gauss (5 crossings)",  timed_us(() -> canonical_gauss(small)))
classify_sigma("canonical_gauss (10 crossings)", timed_us(() -> canonical_gauss(med)))
classify_sigma("is_equivalent (3 crossings)",    timed_us(() -> is_equivalent(trefoil, rotated)))
classify_sigma("mirror (3 crossings)",           timed_us(() -> mirror(trefoil)))
classify_sigma("simplify_r1 (3 crossings)",      timed_us(() -> simplify_r1(trefoil)))

println()

# ── 3. Database operations ─────────────────────────────────────────────────────
println("─── Database operations ───────────────────────────────────────────────")

classify_sigma("SkeinDB open/close", timed_us(() -> begin
    db = SkeinDB(":memory:")
    close(db)
end; warmup=1, trials=50))

db = SkeinDB(":memory:")
gc = GaussCode([1, -2, 3, -1, 2, -3])

classify_sigma("store! (single knot)", timed_us(() -> begin
    name = "bench_$(rand(UInt64))"
    store!(db, name, gc)
end; warmup=1, trials=50))

for i in 1:100
    n = rand(0:8)
    store!(db, "qbench_$i", random_gauss(n))
end

classify_sigma("fetch_knot (by name)",         timed_us(() -> fetch_knot(db, "qbench_50")))
classify_sigma("query (crossing_number=3)",    timed_us(() -> query(db, crossing_number=3)))
classify_sigma("query (crossing_number=0:4)",  timed_us(() -> query(db, crossing_number=0:4)))
classify_sigma("query (composable predicate)", timed_us(() -> query(db, crossing(3) | crossing(4))))
classify_sigma("haskey (existing)",            timed_us(() -> haskey(db, "qbench_1")))
classify_sigma("haskey (missing)",             timed_us(() -> haskey(db, "nonexistent_key")))
classify_sigma("count_knots",                  timed_us(() -> Skein.count_knots(db)))
classify_sigma("statistics",                   timed_us(() -> Skein.statistics(db); warmup=1, trials=50))

println()

# ── 4. Bulk operations ─────────────────────────────────────────────────────────
println("─── Bulk operations ───────────────────────────────────────────────────")

classify_sigma("bulk_import! (50 knots)", timed_us(() -> begin
    bdb = SkeinDB(":memory:")
    knots = [("bulk_$i", random_gauss(rand(0:6))) for i in 1:50]
    bulk_import!(bdb, knots)
    close(bdb)
end; warmup=1, trials=20))

classify_sigma("import_knotinfo! (9 knots)", timed_us(() -> begin
    bdb = SkeinDB(":memory:")
    Skein.import_knotinfo!(bdb)
    close(bdb)
end; warmup=1, trials=20))

println()

# ── 5. Export operations ───────────────────────────────────────────────────────
println("─── Export operations ─────────────────────────────────────────────────")

export_db = SkeinDB(":memory:")
for i in 1:50
    store!(export_db, "exp_$i", random_gauss(rand(0:6)))
end

tmpcsv  = tempname() * ".csv"
tmpjson = tempname() * ".json"

classify_sigma("export_csv (50 knots)",  timed_us(() -> Skein.export_csv(export_db, tmpcsv);  warmup=1, trials=20))
classify_sigma("export_json (50 knots)", timed_us(() -> Skein.export_json(export_db, tmpjson); warmup=1, trials=20))

rm(tmpcsv;  force=true)
rm(tmpjson; force=true)
close(export_db)

println()

# ── 6. Equivalence search ──────────────────────────────────────────────────────
println("─── Equivalence search ────────────────────────────────────────────────")

eq_db = SkeinDB(":memory:")
Skein.import_knotinfo!(eq_db)
unknot_gc = GaussCode([1, -1])

classify_sigma("find_equivalents (in 9-knot DB)", timed_us(() -> find_equivalents(eq_db, trefoil); trials=50))
classify_sigma("find_isotopic (in 9-knot DB)",    timed_us(() -> find_isotopic(eq_db, unknot_gc); trials=50))

close(eq_db)
close(db)

println()

# ── Summary ────────────────────────────────────────────────────────────────────
println("─── Six Sigma Summary ─────────────────────────────────────────────────")
total = sum(values(_SIGMA_COUNTS))
if _SIGMA_COUNTS[:baseline] == total
    println("  BASELINE RUN — no prior measurements.  Record the μs values above.")
    println("  Copy them into the BASELINES dict and re-run to classify.")
else
    hard_fails = _SIGMA_COUNTS[:unacceptable]
    soft_fails = _SIGMA_COUNTS[:acceptable]
    @printf("  Baseline:      %d\n", _SIGMA_COUNTS[:baseline])
    @printf("  Extraordinary: %d\n", _SIGMA_COUNTS[:extraordinary])
    @printf("  Ordinary:      %d\n", _SIGMA_COUNTS[:ordinary])
    @printf("  Acceptable:    %d  (soft fail)\n", soft_fails)
    @printf("  Unacceptable:  %d  (HARD FAIL)\n", hard_fails)
    println()
    if hard_fails > 0
        println("  RESULT: FAIL — $(hard_fails) hard regression(s)")
    elseif soft_fails > 0
        println("  RESULT: WARN — $(soft_fails) soft regression(s), no hard fails")
    else
        println("  RESULT: PASS")
    end
end

println("\n=== Done ===")
