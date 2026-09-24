#!/bin/bash
# tests/sms-loop.sh — SMS loop: multipart + delivery reports + dedupe (ch.10 §7).
# Phone-safe: sends only on lab units with HALIDE_LAB_CALLS=1; evidence redacted.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_LAB_CALLS:-0}" != "1" ] || [ -z "${HALIDE_LAB_TARGET:-}" ]; then
  echo "SKIP: SMS sends need HALIDE_LAB_CALLS=1 + HALIDE_LAB_TARGET (lab SIM only) (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/sms-loop-$(date +%Y%m%d-%H%M%S).csv
echo "idx,parts,dr_received,dedup_ok" > "$OUT"
FAIL=0
declare -A SEEN
for i in $(seq 1 "${HALIDE_SMS_N:-20}"); do
  BODY="halide-loop $i $(printf 'x%.0s' $(seq 1 200))"   # >160 chars → multipart path
  RES=$(adb shell halide-sms-drive --send "$HALIDE_LAB_TARGET" --text "$BODY" --await-dr 60 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
  case "$RES" in
    *tool-missing*) echo "SKIP: halide-sms-drive not on unit (device/builder only)"; exit 2 ;;
  esac
  PARTS=$(echo "$RES" | grep -o 'parts=[0-9]*' | cut -d= -f2 || echo "?")
  DR=$(echo "$RES" | grep -o 'dr=[A-Z]*' || echo "dr=MISSING")
  PDU=$(echo "$RES" | grep -o 'pdu_hash=[0-9a-f]*' | cut -d= -f2 || echo "nohash")
  DEDUP=ok
  if [ -n "${SEEN[$PDU]:-}" ]; then DEDUP=DUPLICATE; FAIL=1; fi   # modem retransmit re-assembled twice?
  SEEN[$PDU]=1
  printf '%s,%s,%s,%s\n' "$i" "${PARTS:-?}" "$DR" "$DEDUP" | emit >> "$OUT"
  [ "$DR" = "dr=DELIVERED" ] || { echo "FAIL: leg $i no delivery report ($DR)"; FAIL=1; }
done
echo "sms-loop: legs in $OUT" | emit
[ "$FAIL" = 0 ] && echo "sms-loop: PASS" || echo "sms-loop: FAIL"
exit "$FAIL"
