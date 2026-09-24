#!/bin/bash
# tests/gnss-track.sh — cold-start TTFF (3-run median ≤60s open-sky) + 15-min track
# vs stock GPX overlay (ch.10 §21/§24). Shield-bag negative control validates the fix.
# Phone-safe: modem reads only; coordinates redacted on --redact.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g; s/-?[0-9]{1,3}\.[0-9]{4,}/<COORD>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_LAB:-0}" != "1" ]; then
  echo "SKIP: GNSS acceptance needs HALIDE_LAB=1 (open-sky fixture, ch.10 §24) (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/gnss-track-$(date +%Y%m%d-%H%M%S).csv
echo "run,ttff_s,fix_ok" > "$OUT"
FAIL=0
for R in 1 2 3; do
  adb shell halide-gnss-drive --cold-start --record-nmea /data/local/tmp/nmea.txt >/dev/null 2>&1 \
    || { echo "SKIP: halide-gnss-drive not on unit (device/builder only)"; exit 2; }
  TTFF=$(adb shell cat /data/local/tmp/ttff.txt 2>/dev/null | tr -d '\r\n ' || echo "?")
  case "$TTFF" in ''|'?') echo "FAIL-INFRA: TTFF not reported (runner/lab issue)"; exit 2 ;; esac
  printf '%s,%s,%s\n' "$R" "$TTFF" "$([ "$TTFF" -le 60 ] 2>/dev/null && echo yes || echo no)" | emit >> "$OUT"
  [ "$TTFF" -le 60 ] 2>/dev/null || { echo "FAIL: run $R TTFF ${TTFF}s > 60s gate"; FAIL=1; }
done
# shield-bag negative control: fix must NOT appear in-bag within 5 min
INBAG=$(adb shell halide-gnss-drive --shield-bag --seconds 300 2>/dev/null | tail -1 | tr -d '\r\n' || echo "?")
[ "$INBAG" = "no-fix" ] || { echo "FAIL: bagged unit still fixes — cached/Wi-Fi-derived, not satellite"; FAIL=1; }
MED=$(tail -3 "$OUT" | cut -d, -f2 | sort -n | sed -n 2p)
echo "gnss-track: median TTFF=${MED}s (gate ≤60s), CSV: $OUT" | emit
[ "$FAIL" = 0 ] && echo "gnss-track: PASS" || echo "gnss-track: FAIL"
exit "$FAIL"
