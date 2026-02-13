;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(neurosym
  (metadata
    (version "0.1.0")
    (last-updated "2026-02-13"))

  (symbolic-reasoning
    (domain "knot-theory")
    (representations
      (representation "gauss-code" (type "signed-integer-sequence") (properties "cyclic" "paired"))
      (representation "crossing-number" (type "non-negative-integer") (invariant true))
      (representation "writhe" (type "integer") (invariant false) (note "diagram-dependent")))
    (equivalence-relations
      (relation "diagram-equivalence" (operations "cyclic-rotation" "relabelling"))
      (relation "r1-isotopy" (operations "reidemeister-1" "cyclic-rotation" "relabelling")))))
