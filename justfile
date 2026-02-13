# SPDX-License-Identifier: PMPL-1.0-or-later
# Skein.jl justfile
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

# List all available recipes
default:
    @just --list

# Run the test suite
test:
    julia --project=. -e 'using Pkg; Pkg.test()'

# Run benchmarks
bench:
    julia --project=. benchmark/benchmarks.jl

# Resolve and instantiate dependencies
deps:
    julia --project=. -e 'using Pkg; Pkg.resolve(); Pkg.instantiate()'

# Update dependencies
update:
    julia --project=. -e 'using Pkg; Pkg.update()'

# Import KnotInfo table into a database
import-knotinfo db="knots.db":
    julia --project=. -e 'using Skein; db = SkeinDB("{{db}}"); n = Skein.import_knotinfo!(db); println("Imported $n knots"); close(db)'

# Export database to CSV
export-csv db="knots.db" output="knots.csv":
    julia --project=. -e 'using Skein; db = SkeinDB("{{db}}"); n = Skein.export_csv(db, "{{output}}"); println("Exported $n knots"); close(db)'

# Export database to JSON
export-json db="knots.db" output="knots.json":
    julia --project=. -e 'using Skein; db = SkeinDB("{{db}}"); n = Skein.export_json(db, "{{output}}"); println("Exported $n knots"); close(db)'

# Show database statistics
stats db="knots.db":
    julia --project=. -e 'using Skein; db = SkeinDB("{{db}}"); s = Skein.statistics(db); println(s); close(db)'

# Run the example script
example:
    julia --project=. examples/knot_table.jl

# Start Julia REPL with Skein loaded
repl:
    julia --project=. -e 'using Skein; println("Skein.jl loaded")' -i
