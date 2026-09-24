#!/bin/bash
# workload-jank.sh — REF-A jank workload plan (ch.06 S14). Text-only on phone: prints the
# fixed workload + checks limits.conf values sane; it NEVER drives the device (lab runs the
# workload on-device with halide-frame-trace; this repo shell stays plan-only, NO-COMPILE mode).
# Exit contract: 0 = plan OK, 1 = config sanity fail, 2 = refused (device/builder-only path).
set -eu
cd "$(dirname "$0")/.."

# Refuse anything that looks like a device run — traces are captured on the bench, not here.
if [ -e /dev/dri/card0 ]; then
  echo "REFUSED: device present — run the workload from the lab bench with halide-frame-trace, not from this repo shell"
  exit 2
fi

LIMITS=graphics/refa/limits.conf
[ -f "$LIMITS" ] || { echo "FAIL-INFRA: $LIMITS missing"; exit 2; }

# Sanity: composer limits must stay within the power budget (ch.06 S11 / power/refa/budget.md)
max_layers=$(sed -n 's/^max_layers=//p' "$LIMITS" | head -1)
max_fps=$(sed -n 's/^max_fps=//p' "$LIMITS" | head -1)
if [ -z "$max_layers" ] || [ -z "$max_fps" ]; then
  echo "FAIL: max_layers/max_fps missing in $LIMITS"; exit 1
fi
if [ "$max_layers" -lt 1 ] || [ "$max_layers" -gt 8 ]; then
  echo "FAIL: max_layers=$max_layers out of range 1..8"; exit 1
fi
if [ "$max_fps" -lt 30 ] || [ "$max_fps" -gt 90 ]; then
  echo "FAIL: max_fps=$max_fps out of range 30..90"; exit 1
fi

echo "workload-jank plan (fixed, same every release — ch.06 S14):"
echo "  1. F-Droid list fling x5"
echo "  2. 720p video 60s"
echo "  3. drawer open/close x10"
echo "capture: halide-frame-trace --duration 30 -> frame-join.csv (SEQ-joined)"
echo "report:  missed-vsync %, p50/p95 frame time, fence-wait p95 <=8ms, import p95"
echo "limits:  max_layers=$max_layers max_fps=$max_fps — OK"
exit 0
