;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(state
  (metadata
    (version "0.2.0")
    (last-updated "2026-02-13")
    (status active))

  (project-context
    (name "Skein.jl")
    (purpose "Knot-theoretic database for Julia — store, index, and query knots by topological invariants")
    (completion-percentage 75))

  (components
    (component "core-types" (status complete) (description "GaussCode, KnotRecord types"))
    (component "invariants" (status complete) (description "crossing_number, writhe, gauss_hash, normalise_gauss"))
    (component "equivalence" (status complete) (description "canonical_gauss, is_equivalent, is_isotopic, mirror, simplify_r1"))
    (component "storage" (status complete) (description "SQLite backend with WAL, schema v2, CRUD operations"))
    (component "query" (status complete) (description "Keyword queries, composable predicates with & and |"))
    (component "import-export" (status complete) (description "CSV, JSON export; KnotInfo import; bulk import"))
    (component "knottheory-ext" (status complete) (description "Package extension for KnotTheory.jl integration"))
    (component "jones-polynomial" (status partial) (description "Column exists; auto-computed via KnotTheory.jl extension"))
    (component "registry" (status pending) (description "Julia General registry submission")))

  (route-to-mvp
    (milestone "v0.1.0" (status complete) (description "Core types, storage, queries, tests passing"))
    (milestone "v0.2.0" (status complete) (description "KnotTheory.jl ext, Jones column, KnotInfo import, query DSL, equivalence"))
    (milestone "v0.3.0" (status pending) (description "Registry submission, richer invariants, Reidemeister II/III")))

  (blockers-and-issues
    (issue "amphichiral-detection" (severity low) (description "Full amphichirality requires Reidemeister II/III beyond current R1")))

  (critical-next-actions
    (action "Submit to Julia General registry")
    (action "Add Reidemeister II/III simplification")
    (action "Benchmark with large knot tables (10+ crossings)")))
