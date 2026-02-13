<!-- SPDX-License-Identifier: PMPL-1.0-or-later -->
<!-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk> -->

# Contributing to Skein.jl

Thank you for your interest in contributing to Skein.jl!

## Prerequisites

- Julia 1.10 or later
- Git

## Development Setup

```bash
git clone https://github.com/hyperpolymath/Skein.jl
cd Skein.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Running Tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Running Benchmarks

```bash
julia --project=. benchmark/benchmarks.jl
```

## Repository Structure

```
Skein.jl/
├── src/                  # Package source
│   ├── Skein.jl          # Module entry point
│   ├── types.jl          # Core types (GaussCode, KnotRecord)
│   ├── invariants.jl     # Invariant computation and equivalence
│   ├── storage.jl        # SQLite backend
│   ├── query.jl          # Query DSL and predicates
│   └── import_export.jl  # CSV/JSON/KnotInfo import/export
├── ext/                  # Package extensions
│   └── KnotTheoryExt.jl  # KnotTheory.jl integration
├── test/                 # Test suite
│   └── runtests.jl       # All tests (493+)
├── benchmark/            # Performance benchmarks
├── examples/             # Usage examples
├── .machine_readable/    # SCM metadata files
├── .bot_directives/      # Bot-specific rules
└── contractiles/         # Operational framework
```

## How to Contribute

### Reporting Bugs

Open an issue with:
- Julia version (`versioninfo()`)
- Minimal reproduction case
- Expected vs actual behaviour

### Code Contributions

1. Fork the repository
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

### Code Style

- Follow Julia conventions (4-space indent)
- Add docstrings to all public functions
- Include SPDX header on new files:
  ```julia
  # SPDX-License-Identifier: PMPL-1.0-or-later
  # Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>
  ```

### Adding Knot Invariants

To add a new invariant:

1. Add the computation function to `src/invariants.jl`
2. Add a column to the schema in `src/storage.jl` (with migration)
3. Update `store!`, `fetch_knot`, and `row_to_record`
4. Add query support in `src/query.jl`
5. Add tests and update the benchmark suite

## Licence

By contributing, you agree that your contributions will be licensed under PMPL-1.0-or-later.
