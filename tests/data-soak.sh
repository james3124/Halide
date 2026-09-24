#!/bin/bash
# tests/data-soak.sh — iperf soak + data-detach detector (ch.10 §7).
# Default 1h soak on lab unit (HALIDE_LAB=1); detach counts go to CSV, redacted.
# Phone-safe: network traffic only on lab units; no config changes.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_LAB:-0}" != "1" ] || [ -z "${HALIDE_IPERF_SERVER:-}" ]; then
  echo "SKIP: needs HALIDE_LAB=1 + HALIDE_IPERF_SERVER (lab network + server, ch.10 §7) (device/builder only)"; exit 2
fi
MINS="${HALIDE_SOAK_MIN:-60}"   # lab override only; nightly keeps 60
mkdir -p logs
OUT=logs/data-soak-$(date +%Y%m%d-%H%M%S).csv
echo "t_min,attached,rx_mbps" > "$OUT"
FAIL=0
DETACH=0
adb shell iperf3 -s -1 >/dev/null 2>&1 || true   # on-unit server for the loop test
for i in $(seq 1 "$MINS"); do
  R=$(adb shell halide-data-drive --probe --server "$HALIDE_IPERF_SERVER" --seconds 55 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
  case "$R" in
    *tool-missing*) echo "SKIP: halide-data-drive not on unit (device/builder only)"; exit 2 ;;
  esac
  ATT=$(echo "$R" | grep -o 'attached=[a-z]*' | cut -d= -f2 || echo "?")
  MBPS=$(echo "$R" | grep -o 'rx_mbps=[0-9.]*' | cut -d= -f2 || echo "0")
  [ "$ATT" = "yes" ] || DETACH=$((DETACH+1))
  printf '%s,%s,%s\n' "$i" "$ATT" "$MBPS" | emit >> "$OUT"
done
echo "data-soak: $MINS min done, detach_events=$DETACH (CSV: $OUT)" | emit
# detach needing manual recovery = P0 (ch.10 §10); any unexplained detach fails here
if [ "$DETACH" -gt 0 ]; then
  echo "FAIL: $DETACH detach event(s) during soak — investigate per ch.07 §15 ladder, do not normalize"; FAIL=1
fi
[ "$FAIL" = 0 ] && echo "data-soak: PASS" || echo "data-soak: FAIL"
exit "$FAIL"
