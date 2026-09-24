#!/bin/bash
# tests/call-loop.sh — MO/MT alternating call loop + hangup-cause log (ch.10 §7).
# Phone-safe: dials only on a lab unit with HALIDE_LAB_CALLS=1 and a lab target
# number; audio-record + hangup-cause per call logged to CSV (redacted on --redact).
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_LAB_CALLS:-0}" != "1" ] || [ -z "${HALIDE_LAB_TARGET:-}" ]; then
  echo "SKIP: MO calls need HALIDE_LAB_CALLS=1 + HALIDE_LAB_TARGET (lab SIM + callbox, ch.10 §7) (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/call-loop-$(date +%Y%m%d-%H%M%S).csv
echo "leg,direction,setup_ok,drop,hangup_cause,note" > "$OUT"
FAIL=0
for i in $(seq 1 "${HALIDE_CALLS:-10}"); do
  if [ $((i % 2)) -eq 1 ]; then DIR=MO; ACT=dial; else DIR=MT; ACT=wait-incoming; fi
  # host owns the modem (ch.07 §1): calls ride the bridge, container never dials raw
  RES=$(adb shell halide-call-drive --$ACT --target "$HALIDE_LAB_TARGET" --hangup-after 20 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
  case "$RES" in
    *tool-missing*) echo "SKIP: halide-call-drive not on unit (device/builder only)"; exit 2 ;;
    *cause=*|*OK*) CAUSE=$(echo "$RES" | grep -o 'cause=[0-9]*' || echo "cause=0") ;;
    *) CAUSE="cause=?"; FAIL=1 ;;
  esac
  printf '%s,%s,%s,%s,%s,%s\n' "$i" "$DIR" "$([ "$FAIL" = 0 ] && echo yes || echo no)" \
    "$([ "$CAUSE" = "cause=0" ] && echo no || echo yes)" "$CAUSE" "audio-record=slice" | emit >> "$OUT"
done
echo "call-loop: legs done, hangup causes in $OUT" | emit
[ "$FAIL" = 0 ] && echo "call-loop: PASS" || echo "call-loop: FAIL (see $OUT)"
exit "$FAIL"
