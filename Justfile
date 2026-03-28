# SPDX-License-Identifier: PMPL-1.0-or-later
# Skein.jl justfile
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

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

# Run panic-attacker pre-commit scan
assail:
    @command -v panic-attack >/dev/null 2>&1 && panic-attack assail . || echo "panic-attack not found — install from https://github.com/hyperpolymath/panic-attacker"

# ═══════════════════════════════════════════════════════════════════════════════
# ONBOARDING & DIAGNOSTICS
# ═══════════════════════════════════════════════════════════════════════════════

# Check all required toolchain dependencies and report health
doctor:
    #!/usr/bin/env bash
    echo "═══════════════════════════════════════════════════"
    echo "  Skein.Jl Doctor — Toolchain Health Check"
    echo "═══════════════════════════════════════════════════"
    echo ""
    PASS=0; FAIL=0; WARN=0
    check() {
        local name="$1" cmd="$2" min="$3"
        if command -v "$cmd" >/dev/null 2>&1; then
            VER=$("$cmd" --version 2>&1 | head -1)
            echo "  [OK]   $name — $VER"
            PASS=$((PASS + 1))
        else
            echo "  [FAIL] $name — not found (need $min+)"
            FAIL=$((FAIL + 1))
        fi
    }
    check "just"              just      "1.25" 
    check "git"               git       "2.40" 
    check "Zig"               zig       "0.13" 
    check "Julia"             julia     "1.10" 
# Optional tools
if command -v panic-attack >/dev/null 2>&1; then
    echo "  [OK]   panic-attack — available"
    PASS=$((PASS + 1))
else
    echo "  [WARN] panic-attack — not found (pre-commit scanner)"
    WARN=$((WARN + 1))
fi
    echo ""
    echo "  Result: $PASS passed, $FAIL failed, $WARN warnings"
    if [ "$FAIL" -gt 0 ]; then
        echo "  Run 'just heal' to attempt automatic repair."
        exit 1
    fi
    echo "  All required tools present."

# Attempt to automatically install missing tools
heal:
    #!/usr/bin/env bash
    echo "═══════════════════════════════════════════════════"
    echo "  Skein.Jl Heal — Automatic Tool Installation"
    echo "═══════════════════════════════════════════════════"
    echo ""
if ! command -v just >/dev/null 2>&1; then
    echo "Installing just..."
    cargo install just 2>/dev/null || echo "Install just from https://just.systems"
fi
    echo ""
    echo "Heal complete. Run 'just doctor' to verify."

# Guided tour of the project structure and key concepts
tour:
    #!/usr/bin/env bash
    echo "═══════════════════════════════════════════════════"
    echo "  Skein.Jl — Guided Tour"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo '// SPDX-License-Identifier: PMPL-1.0-or-later'
    echo ""
    echo "Key directories:"
    echo "  src/                      Source code" 
    echo "  ffi/                      Foreign function interface (Zig)" 
    echo "  src/abi/                  Idris2 ABI definitions" 
    echo "  tests/                    Test suite" 
    echo "  test/                     Test suite" 
    echo "  .github/workflows/        CI/CD workflows" 
    echo "  contractiles/             Must/Trust/Dust contracts" 
    echo "  .machine_readable/        Machine-readable metadata" 
    echo "  examples/                 Usage examples" 
    echo ""
    echo "Quick commands:"
    echo "  just doctor    Check toolchain health"
    echo "  just heal      Fix missing tools"
    echo "  just help-me   Common workflows"
    echo "  just default   List all recipes"
    echo ""
    echo "Read more: README.adoc, EXPLAINME.adoc"

# Show help for common workflows
help-me:
    #!/usr/bin/env bash
    echo "═══════════════════════════════════════════════════"
    echo "  Skein.Jl — Common Workflows"
    echo "═══════════════════════════════════════════════════"
    echo ""
echo "FIRST TIME SETUP:"
echo "  just doctor           Check toolchain"
echo "  just heal             Fix missing tools"
echo "" 
echo "PRE-COMMIT:"
echo "  just assail           Run panic-attacker scan"
echo ""
echo "LEARN:"
echo "  just tour             Guided project tour"
echo "  just default          List all recipes" 
