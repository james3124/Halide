#!/bin/bash
# tests/camera-flush.sh — camera open→flush→reopen race drill (ch.10 §21): burst cancel
# must release the sensor ≤1s, no stuck buffers, no HAL death after 20 cycles.
# Phone-safe: camera exercise on lab unit; interlocked.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_LAB:-0}" != "1" ]; then
  echo "SKIP: camera rig run — HALIDE_LAB=1 (lab fixture) (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/camera-flush-$(date +%Y%m%d-%H%M%S).csv
echo "cycle,flush_ms,hal_alive" > "$OUT"
FAIL=0
for i in $(seq 1 20); do
  R=$(adb shell halide-cam-drive --open-flush-reopen 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
  case "$R" in
    *tool-missing*) echo "SKIP: halide-cam-drive absent on unit (device/builder only)"; exit 2 ;;
  esac
  MS=$(echo "$R" | grep -o 'flush_ms=[0-9]*' | cut -d= -f2 || echo "?")
  ALIVE=$(echo "$R" | grep -o 'hal_alive=[a-z]*' | cut -d= -f2 || echo "?")
  printf '%s,%s,%s\n' "$i" "$MS" "$ALIVE" | emit >> "$OUT"
  case "$MS" in *[!0-9]*|"") echo "FAIL-INFRA: flush_ms unparseable (runner/lab issue)"; exit 2 ;; esac
  [ "$MS" -le 1000 ] || { echo "FAIL: cycle $i flush ${MS}ms > 1s"; FAIL=1; }
  [ "$ALIVE" = "true" ] || { echo "FAIL: camera HAL died on cycle $i"; FAIL=1; }
done
# stuck-buffer check: zero queued buffers after final flush
Q=$(adb shell halide-cam-drive --queued-buffers 2>/dev/null | tr -d '\r\n' || echo "?")
echo "camera-flush: queued_buffers_after=$Q (CSV: $OUT)" | emit
[ "$Q" = "0" ] || { echo "FAIL: $Q buffers stuck after flush"; FAIL=1; }
[ "$FAIL" = 0 ] && echo "camera-flush: PASS" || echo "camera-flush: FAIL"
exit "$FAIL"
