;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(agentic
  (metadata
    (version "0.1.0")
    (last-updated "2026-02-13"))

  (agent-capabilities
    (capability "knot-storage" (description "Store and retrieve knots by Gauss code"))
    (capability "invariant-query" (description "Query knots by computed topological invariants"))
    (capability "equivalence-check" (description "Detect equivalent knot diagrams")))

  (integration-points
    (point "knottheory-ext" (trigger "KnotTheory.jl loaded") (action "Enable PlanarDiagram storage and Jones polynomial computation"))))
