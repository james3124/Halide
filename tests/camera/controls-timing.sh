#!/bin/bash
# tests/camera/controls-timing.sh - exposure/focus/WB converge timers (ch.10 S21/S24).
# Each control must converge <=3s, 5 repeats, median reported. Tuning constants in
# camera/<sku>/tuning.json versioned with goldens (tuning change without golden
# re-sign fails review). Phone-safe: lab unit HALIDE_LAB=1 only. Exit 0/1/2.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/../.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_LAB:-0}" != "1" ]; then
  echo "SKIP: camera rig run needs HALIDE_LAB=1 (lab fixture, test-cards only) (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/controls-timing-$(date +%Y%m%d-%H%M%S).csv
echo "control,run,seconds" > "$OUT"
FAIL=0
for C in exposure focus wb; do
  for R in 1 2 3 4 5; do
    T=$(adb shell halide-cam-drive --converge "$C" 2>/dev/null | tr -d '\r\n ' || echo "?")
    case "$T" in ''|'?') echo "SKIP: halide-cam-drive not on unit (device/builder only)"; exit 2 ;; esac
    echo "$C,$R,$T" | emit >> "$OUT"
  done
  MED=$(grep "^$C," "$OUT" | cut -d, -f3 | sort -n | sed -n 3p)
  echo "controls-timing: $C median ${MED}s (gate <=3s)" | emit
  python3 -c "import sys; sys.exit(0 if '$MED'.replace('.','',1).isdigit() and float('$MED') <= 3.0 else 1)" \
    || { echo "FAIL: $C converge median ${MED}s > 3s"; FAIL=1; }
done
[ "$FAIL" = 0 ] && echo "controls-timing: PASS" || echo "controls-timing: FAIL"
exit "$FAIL"
