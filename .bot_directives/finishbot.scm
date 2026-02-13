;; SPDX-License-Identifier: PMPL-1.0-or-later
;; Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

(bot-directive
  (bot "finishbot")
  (scope "release readiness checks")
  (allow ("analysis" "report" "tag-suggestion"))
  (deny ("create-release" "push-tags"))
  (notes "Validates release readiness; tagging requires human approval"))
