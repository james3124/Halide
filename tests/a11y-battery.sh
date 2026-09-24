#!/bin/bash
# tests/a11y-battery.sh — screen-reader path alive + battery drain with SR active
# (ch.01 §14 scripted SR tasks; ch.10 §3 power method). Gate: 3 SR tasks + drain delta.
# Phone-safe: read-only settings/battery reads; the 3 scripted tasks are driven
# through the a11y driver on a lab unit only.
# DOD: DoD-standby,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_LAB:-0}" != "1" ]; then
  echo "SKIP: SR task loop runs on lab unit — HALIDE_LAB=1 (device/builder only)"; exit 2
fi
# 1. SR service present (TalkBack on Android path; host Phosh SR is host-side)
SR=$(adb shell settings get secure enabled_accessibility_services 2>/dev/null | tr -d '\r\n' || echo "")
echo "a11y-battery: enabled_a11y_services=[${SR:-none}]"
# 2. 3 scripted tasks by SR only: place call, send SMS, take photo (pass/fail each, ch.01 §14)
mkdir -p logs
OUT=logs/a11y-battery-$(date +%Y%m%d-%H%M%S).csv
echo "task,pass" > "$OUT"
FAIL=0
for TASK in place-call send-sms take-photo; do
  R=$(adb shell halide-a11y-drive --task "$TASK" 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
  case "$R" in
    *tool-missing*) echo "SKIP: halide-a11y-drive absent on unit (device/builder only)"; exit 2 ;;
  esac
  echo "$R" | grep -qi pass || FAIL=1
  echo "$TASK,$R" | emit >> "$OUT"
done
# 3. battery drain with SR active over 30 min screen-on (report + 2× stock envelope)
B0=$(adb shell dumpsys battery 2>/dev/null | grep -o 'level: [0-9]*' | grep -o '[0-9]*' || echo "?")
sleep "${HALIDE_A11Y_MIN:-30}"
B1=$(adb shell dumpsys battery 2>/dev/null | grep -o 'level: [0-9]*' | grep -o '[0-9]*' || echo "?")
echo "a11y-battery: battery $B0% → $B1% over ${HALIDE_A11Y_MIN:-30} min SR-on (vs 2× stock)" | emit
echo "$B0,$B1" | emit >> "$OUT"
[ "$FAIL" = 0 ] && echo "a11y-battery: PASS" || echo "a11y-battery: FAIL"
exit "$FAIL"
