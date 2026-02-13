;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(bot-directive
  (bot "rhodibot")
  (scope "RSR compliance checks")
  (allow ("analysis" "lint" "report"))
  (deny ("write to src/" "write to ext/" "write to test/"))
  (notes "Validates RSR template compliance; read-only analysis"))
