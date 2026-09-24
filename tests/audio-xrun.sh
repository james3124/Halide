#!/bin/bash
# tests/audio-xrun.sh — underrun/overrun audit per ch.05 §31 observability block.
# Asserts audio.metrics counters: xrun_total == 0 wired, ≤3 BT (reason-tagged).
# Phone-safe: reads metrics + pw-top; never restarts the audio daemon.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

check_counters() { # $1 = metrics text, $2 = label, $3 = max allowed
  P=$(echo "$1" | grep -o 'playback_xrun_total=[0-9]*' | cut -d= -f2 || echo "?")
  C=$(echo "$1" | grep -o 'capture_xrun_total=[0-9]*' | cut -d= -f2 || echo "?")
  echo "audio-xrun: $2 playback=$P capture=$C (max $3)"
  case "${P}${C}" in *[!0-9]*) echo "FAIL-INFRA: metrics unparseable on $2 (runner/lab issue)"; exit 2 ;; esac
  [ "$P" -le "$3" ] && [ "$C" -le "$3" ] || { echo "FAIL: xrun counters exceed $3 on $2"; return 1; }
}

# 1. wired: counters must be 0
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  MET=$(adb shell cat /run/halide/audio.metrics 2>/dev/null | tr -d '\r' || echo "no-metrics")
  if [ "$MET" = "no-metrics" ] || [ -z "$MET" ]; then
    echo "SKIP: no /run/halide/audio.metrics on unit (device/builder only)"; exit 2
  fi
  check_counters "$MET" "wired" 0 || FAIL=1
  # 2. BT A2DP: ≤3 with bt-jitter reason tag
  BT=$(adb shell halide-audio-drive --bt-report 2>/dev/null | tail -1 | tr -d '\r' || echo "")
  if [ -n "$BT" ]; then
    check_counters "$BT" "bt-a2dp" 3 || FAIL=1
    echo "$BT" | grep -q 'bt-jitter' || echo "note: BT xruns untagged — ch.05 §31 wants reasons"
  fi
else
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
[ "$FAIL" = 0 ] && echo "audio-xrun: PASS" || echo "audio-xrun: FAIL"
exit "$FAIL"
