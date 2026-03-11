;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(meta
  (metadata
    (version "0.1.0")
    (last-updated "2026-02-13"))

  (project-info
    (type library)
    (languages (julia))
    (license "PMPL-1.0-or-later"))

  (architecture-decisions
    (adr "gauss-code-primary"
      (status accepted)
      (description "Use Gauss codes as the primary knot representation")
      (rationale "Compact, well-studied, serialisable, and sufficient for invariant computation"))
    (adr "sqlite-backend"
      (status accepted)
      (description "Use SQLite for storage via SQLite.jl")
      (rationale "Zero-configuration, WAL mode for concurrent reads, familiar SQL queries"))
    (adr "weakdep-extension"
      (status accepted)
      (description "KnotTheory.jl integration via Julia package extensions (weakdeps)")
      (rationale "Avoids hard dependency on KnotTheory.jl; loads only when both packages present"))
    (adr "invariants-on-insert"
      (status accepted)
      (description "Compute and store invariants at insert time, not query time")
      (rationale "Amortises cost; enables indexed queries on invariant columns")))

  (development-practices
    (testing "Property-based tests for invariant consistency; round-trip tests for storage")
    (documentation "Docstrings on all public functions; AsciiDoc README")
    (versioning "SemVer; Julia General registry compatible")))
