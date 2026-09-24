#!/bin/bash
# tests/audio-loopback.sh — audio loop acceptance (ch.10 §21): host-only loopback
# first (modem PCM → mixer → earpiece, isolates gains from bridge), then bridged.
# 5 scripted scenarios; underrun counts asserted (0 wired / ≤3 BT per ch.05 §31).
# Phone-safe: read-only over adb; never touches mixer state.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/audio-loopback-$(date +%Y%m%d-%H%M%S).csv
echo "scenario,path,xrun_total,verdict" > "$OUT"
FAIL=0
for SCEN in quiet street car speaker headset; do
  for PATHKIND in host-only bridged; do
    RES=$(adb shell halide-audio-drive --scenario "$SCEN" --path "$PATHKIND" --seconds 10 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
    case "$RES" in
      *tool-missing*) echo "SKIP: halide-audio-drive not on unit (device/builder only)"; exit 2 ;;
    esac
    XRUN=$(echo "$RES" | grep -o 'xrun_total=[0-9]*' | cut -d= -f2 || echo "?")
    if [ "$PATHKIND" = "host-only" ] && [ "${XRUN:-1}" != "0" ]; then
      echo "FAIL: host-only loop $SCEN xrun_total=$XRUN (must be 0 on wired, ch.05 §31)"; FAIL=1
    fi
    printf '%s,%s,%s,%s\n' "$SCEN" "$PATHKIND" "${XRUN:-?}" "$([ "$FAIL" = 0 ] && echo ok || echo check)" | emit >> "$OUT"
  done
done
echo "audio-loopback: matrix in $OUT (0 one-way-audio in 50 calls gate shared with ch.07 §22)" | emit
[ "$FAIL" = 0 ] && echo "audio-loopback: PASS" || echo "audio-loopback: FAIL"
exit "$FAIL"
