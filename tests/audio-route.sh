#!/bin/bash
# tests/audio-route.sh — audio routing contract: call preempts media (ch.05 §29).
# Text/bridge-level check; live pw-top assertion only on device.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. policy config exists and encodes call priority
if [ -f audio/refa/policy.json ]; then
  grep -qi 'call' audio/refa/policy.json || { echo "FAIL: policy.json has no call role"; FAIL=1; }
  echo "audio-route: policy.json present — OK"
else echo "FAIL: audio/refa/policy.json missing"; FAIL=1; fi

# 2. bridge-level ducking (the preempt rule, text interface)
if python3 - <<'PY'
import sys
sys.path.insert(0, "bridges")
import audio_bridge
a = audio_bridge.handle("ROUTE call\n")
b = audio_bridge.handle("ROUTE media\n")
assert a.startswith("OK routed:call"), a
assert b.startswith("OK ducked"), b
PY
then echo "audio-route: bridge ducks media during call — OK"
else echo "FAIL: call-does-not-preempt-media at bridge level"; FAIL=1; fi

# 3. live node check on device (pw-top ERR column 0 over 60s, ch.05 §31)
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  RES=$(adb shell pw-top -b -n 60 2>/dev/null | tail -5 | tr -d '\r' || echo "tool-missing")
  case "$RES" in
    *tool-missing*|"") echo "note: pw-top not reachable over adb (device/builder only)" ;;
    *) echo "$RES" | grep -q 'ERR 0 0' && echo "audio-route: pw-top ERR 0 0 — OK" \
       || { echo "FAIL: pw-top shows nonzero ERR column"; FAIL=1; } ;;
  esac
else
  echo "SKIP-live: no adb device — static checks only (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "audio-route: PASS"
exit "$FAIL"
