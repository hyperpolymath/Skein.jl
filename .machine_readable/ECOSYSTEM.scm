;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(ecosystem
  (metadata
    (version "0.1.0")
    (last-updated "2026-02-13"))

  (project
    (name "Skein.jl")
    (purpose "Knot-theoretic database for Julia")
    (role persistence-layer))

  (related-projects
    (project "KnotTheory.jl"
      (relationship upstream-computation)
      (integration "Package extension via weakdeps")
      (description "Provides PlanarDiagram, Jones polynomial, Alexander polynomial computation"))
    (project "verisimdb"
      (relationship sibling-standard)
      (description "Vulnerability similarity database — analogous data indexing pattern"))
    (project "hypatia"
      (relationship potential-consumer)
      (description "Neurosymbolic CI/CD — could scan knot data for pattern anomalies"))
    (project "panic-attacker"
      (relationship tooling)
      (description "Security scanning tool — used for supply chain verification")))

  (position-in-ecosystem
    (layer "data-persistence")
    (domain "computational-topology")
    (language "Julia")
    (runtime "Julia 1.10+")))
