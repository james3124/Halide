# edge-reject tuning log (ch06 s23) - append-only, one row per FW x heuristic
# Columns: date | touch_fw | heuristic_edge_vN | L/R/T/B_zone_mm | intentional_tap>=97/100 | ghost_dry | ghost_wet50 | corner_50/50 | grip_20x0taps+typing>=98% | ambient_C | charger_golden? | verdict
# Heuristic constants versioned in hw input-matrix sidecar (edge_vN + rationale link).
# Rules: ghosts at edges -> widen 0.5mm steps (re-measure >=97 guard each step).
# Center ghosts -> FW sensitivity/baseline drift (vendor re-cal + temp note).
# Charging-only ghosts -> charger-noise (charger ID filed, not software tuning).
# Wet-screen unlock ghost storm = Security P0 with spray-fixture photo.
# No rows yet: UNMEASURED - run 100-edge-swipe battery + wet-50 before ship.
