#!/bin/bash
# tests/jank-measure.sh — Perfetto frame_timeline 60s scroll → missed-vsync % (ch.10 §23).
# Gate <5% missed vsync, 10-run median reported (ch.10 §4). Brightness-matched rig
# (200 nits) required or the number is invalid (ch.10 §23).
# Phone-safe: traces on lab unit; nothing on device is modified.
# DOD: DoD-jank,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if ! command -v trace_processor >/dev/null 2>&1; then
  echo "SKIP: trace_processor missing on runner (device/builder only)"; exit 2
fi
if [ "${HALIDE_DISPLAY_RIG:-0}" != "1" ]; then
  echo "SKIP: needs brightness-matched rig HALIDE_DISPLAY_RIG=1 (200 nits, ch.10 §23) (device/builder only)"; exit 2
fi
mkdir -p logs
FAIL=0
declare -a RUNS
for R in 1 2 3 4 5 6 7 8 9 10; do
  T=logs/jank-$R-$(date +%s).pftrace
  adb shell halide-jank-drive --scroll 60 --swipe-velocity 1200 >/dev/null 2>&1 \
    || { echo "SKIP: halide-jank-drive not on unit (device/builder only)"; exit 2; }
  adb shell perfetto -o /data/misc/perfetto-traces/jank.pftrace -t 60s -b 32m sched freq frame_timeline >/dev/null 2>&1 \
    || { echo "FAIL-INFRA: perfetto capture failed (runner/lab issue)"; exit 2; }
  adb pull /data/misc/perfetto-traces/jank.pftrace "$T" >/dev/null
  PCT=$(trace_processor --query-string "select 100.0*count(*)/max(count(*)) over () from frame where jank_type != 'None';" "$T" 2>/dev/null | tail -1 || echo "?")
  case "$PCT" in ''|'?') echo "FAIL-INFRA: frame_timeline parse empty (runner/lab issue)"; exit 2 ;; esac
  RUNS[$R]=$PCT
  echo "jank-measure: run $R missed_vsync=${PCT}%" | emit
  python3 -c "import sys; sys.exit(0 if float('$PCT') < 5.0 else 1)" || FAIL=1
done
MED=$(printf '%s\n' "${RUNS[@]}" | sort -n | sed -n 5p)
echo "jank-measure: 10-run median ${MED}% (gate <5%)" | emit
[ "$FAIL" = 0 ] && echo "jank-measure: PASS" || echo "jank-measure: FAIL"
exit "$FAIL"
