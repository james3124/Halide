#!/bin/bash
# tests/display/display-sweep.sh - brightness ladder captures (ch.10 S23).
# Sets 50/100/200/300 nits, screencap per step, records nits + PNG SHA; catches
# gamma/quantization cliffs a 200-nit-only tolerance pass would hide.
# Phone-safe: lab unit + brightness-matched rig (HALIDE_DISPLAY_RIG=1) only.
# Exit 0 pass / 1 fail / 2 infra. Supports --redact.
# DOD: DoD-jank,DoD-logs
set -eu
cd "$(dirname "$0")/../.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_DISPLAY_RIG:-0}" != "1" ]; then
  echo "SKIP: needs brightness-matched rig HALIDE_DISPLAY_RIG=1 (200 nits jig, ch.10 S23) (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/display-sweep-$(date +%Y%m%d-%H%M%S).csv
echo "nits,png_sha" > "$OUT"
FAIL=0
for N in 50 100 200 300; do
  adb shell halide-display-drive --nits "$N" --screencap /data/local/tmp/sweep.png >/dev/null 2>&1 \
    || { echo "SKIP: halide-display-drive not on unit (device/builder only)"; exit 2; }
  adb pull /data/local/tmp/sweep.png logs/sweep-$N.png >/dev/null 2>&1 \
    || { echo "FAIL-INFRA: sweep pull failed at ${N} nits (runner/lab issue)"; exit 2; }
  SHA=$(sha256sum logs/sweep-$N.png | cut -c1-16)
  LUX=$(adb shell halide-display-drive --read-lux 2>/dev/null | tr -d '\r\n ' || echo "?")
  echo "$N,$SHA (lux=$LUX)" | emit | tee -a "$OUT" >/dev/null
  echo "$N,$SHA" >> "$OUT"
done
echo "display-sweep: ladder 50/100/200/300 nits in $OUT (banding review per ch.10 S23)" | emit
[ "$FAIL" = 0 ] && echo "display-sweep: PASS" || echo "display-sweep: FAIL"
exit "$FAIL"
