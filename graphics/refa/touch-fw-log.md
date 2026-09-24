# touch FW x composer interaction log (ch06 s20) - append-only
# Columns: date | touch_fw (BLOBS.md pin) | composer_build | heuristic_vN | edge100_drops | tap200_p95ms | slots10 | bench_unit | cables_golden? | verdict
# Same unit + same bench every row. Update rule: any FW bump re-runs trio
# (false-reject + latency + slots) before promotion.
# Block bump if: regression >2 drops/100 or +10ms p95 (BUG vs FW/composer pair;
# blame decided by old-composer x new-FW matrix cell, not debate).
# Glove mode (if any): 100 taps >=95, OFF default. Stylus tilt-drop is protocol
# v1 boundary (socket v1), not sensor limit - FW cannot silently widen scope.
# No rows yet: UNMEASURED.
