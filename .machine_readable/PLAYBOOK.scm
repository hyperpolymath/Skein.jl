;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(playbook
  (metadata
    (version "0.1.0")
    (last-updated "2026-02-13"))

  (plays
    (play "test"
      (description "Run the test suite")
      (command "julia --project=. -e 'using Pkg; Pkg.test()'"))
    (play "benchmark"
      (description "Run benchmarks")
      (command "julia --project=. benchmark/benchmarks.jl"))
    (play "import-knotinfo"
      (description "Populate database with standard prime knot table")
      (command "julia --project=. -e 'using Skein; db = SkeinDB(\"knots.db\"); Skein.import_knotinfo!(db); close(db)'"))))
