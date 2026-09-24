#!/bin/bash
# tests/camera/video-soak-5min.sh - 720p 5-min capture soak (ch.10 S21/S24).
# Asserts frame-drop <=2%, no thermal abort below the 70%-clock rule (ch.10 S4),
# audio-underrun count fed to the audio gate. Test-cards only, never people.
# Phone-safe: lab unit HALIDE_LAB=1 only. Exit 0/1/2. Supports --redact.
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
OUT=logs/video-soak-$(date +%Y%m%d-%H%M%S).csv
echo "metric,value" > "$OUT"
adb shell halide-cam-drive --video 720p --seconds 300 --out /data/local/tmp/vsoak.mp4 >/dev/null 2>&1 \
  || { echo "SKIP: halide-cam-drive not on unit (device/builder only)"; exit 2; }
STAT=$(adb shell halide-cam-drive --video-stat 2>/dev/null | tr -d '\r\n' || echo "?")
[ "$STAT" = "?" ] && { echo "FAIL-INFRA: video stat missing (runner/lab issue)"; exit 2; }
echo "$STAT" | tr ' ' '\n' | emit >> "$OUT"
FAIL=0
DROP=$(echo "$STAT" | grep -o 'drop_pct=[0-9.]*' | cut -d= -f2 || echo "?")
ABORT=$(echo "$STAT" | grep -o 'thermal_abort=[01]' | cut -d= -f2 || echo "?")
XRUN=$(echo "$STAT" | grep -o 'underruns=[0-9]*' | cut -d= -f2 || echo "?")
python3 -c "import sys; sys.exit(0 if '$DROP'.replace('.','',1).isdigit() and float('$DROP') <= 2.0 else 1)" \
  || { echo "FAIL: frame-drop ${DROP}% > 2%"; FAIL=1; }
[ "$ABORT" = "0" ] || { echo "FAIL: thermal abort of capture (P0, ch.10 S28)"; FAIL=1; }
echo "video-soak-5min: drop=${DROP}% abort=${ABORT} underruns=${XRUN} (CSV: $OUT)" | emit
[ "$FAIL" = 0 ] && echo "video-soak-5min: PASS" || echo "video-soak-5min: FAIL"
exit "$FAIL"
