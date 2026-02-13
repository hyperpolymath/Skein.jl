# SPDX-License-Identifier: PMPL-1.0-or-later
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

# Building a small knot table with Skein.jl
#
# This example populates a database with the prime knots up to 5 crossings
# and demonstrates basic querying.

using Skein

# Create an in-memory database (use a file path for persistence)
db = SkeinDB(":memory:")

# Prime knots up to 5 crossings, with standard Gauss codes
# Notation: n_k means k-th prime knot with n crossings
prime_knots = [
    ("0_1",  GaussCode(Int[]),                                    # unknot
     Dict("type" => "trivial")),
    ("3_1",  GaussCode([1, -2, 3, -1, 2, -3]),                   # trefoil
     Dict("type" => "torus", "alternating" => "true")),
    ("4_1",  GaussCode([1, -2, 3, -4, 2, -1, 4, -3]),            # figure-eight
     Dict("type" => "twist", "alternating" => "true")),
    ("5_1",  GaussCode([1, -2, 3, -4, 5, -1, 2, -3, 4, -5]),    # (2,5) torus knot
     Dict("type" => "torus", "alternating" => "true")),
    ("5_2",  GaussCode([1, -2, 3, -4, 5, -3, 4, -1, 2, -5]),    # twist knot
     Dict("type" => "twist", "alternating" => "true")),
]

# Bulk insert
println("Populating database...")
for (name, gc, meta) in prime_knots
    store!(db, name, gc; metadata = meta)
end

println("Stored $(Skein.count_knots(db)) knots\n")

# Query examples
println("--- Knots with exactly 3 crossings ---")
for k in query(db, crossing_number = 3)
    println("  ", k.name, " (writhe: ", k.writhe, ")")
end

println("\n--- Knots with 4-5 crossings ---")
for k in query(db, crossing_number = 4:5)
    println("  ", k.name, " (crossings: ", k.crossing_number, ")")
end

println("\n--- Torus knots ---")
for k in query(db, meta = ("type" => "torus"))
    println("  ", k.name)
end

println("\n--- Database statistics ---")
stats = Skein.statistics(db)
println("  Total: ", stats.total_knots, " knots")
println("  Crossing range: ", stats.min_crossings, " to ", stats.max_crossings)
println("  Distribution: ", stats.crossing_distribution)

# Export
tmpfile = tempname() * ".json"
n = Skein.export_json(db, tmpfile)
println("\nExported $n knots to $tmpfile")

close(db)
println("\nDone!")
