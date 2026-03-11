;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(bot-directive
  (bot "robot-repo-automaton")
  (scope "automated fixes with confidence thresholds")
  (allow ("fix-formatting" "fix-metadata" "update-dependencies"))
  (deny ("refactor" "change-api" "modify-tests"))
  (confidence-threshold 0.95)
  (notes "Auto-fix low-risk issues; anything below threshold requires human review"))
