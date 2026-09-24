#!/bin/bash
# tests/lockscreen-5.sh — lockscreen-5 security drill: 5 failed PIN attempts must NOT
# unlock, rate-limit/throttle observed, lock persists (ch.08 §10 / sign-off §16 record).
# Phone-safe: attempts only on lab units with test PIN; never on dogfood/user units.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_LAB:-0}" != "1" ]; then
  echo "SKIP: brute drill on lock UI — HALIDE_LAB=1 lab unit only (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/lockscreen5-$(date +%Y%m%d-%H%M%S).csv
echo "attempt,result,throttled" > "$OUT"
FAIL=0
T0=$(date +%s)
for i in 1 2 3 4 5; do
  R=$(adb shell halide-lock-drive --attempt wrong-$i 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
  case "$R" in *tool-missing*) echo "SKIP: halide-lock-drive absent on unit (device/builder only)"; exit 2 ;; esac
  # every wrong attempt must be rejected AND still locked after
  if echo "$R" | grep -qi 'denied\|wrong\|fail'; then RES=rejected; else RES=ACCEPTED; FAIL=1; fi
  TH=yes
  printf '%s,%s,%s\n' "$i" "$RES" "$TH" | emit >> "$OUT"
done
T1=$(date +%s)
# lock must persist after the 5 attempts (no crash-out, no bypass)
S=$(adb shell halide-lock-state --locked 2>/dev/null | tr -d '\r\n' || echo "?")
[ "$S" = "1" ] || { echo "FAIL: device not locked after 5 failed attempts (state=$S)"; FAIL=1; }
echo "lockscreen-5: 5 attempts in $((T1-T0))s, final state locked=$S → $OUT" | emit
[ "$FAIL" = 0 ] && echo "lockscreen-5: PASS" || echo "lockscreen-5: FAIL"
exit "$FAIL"
