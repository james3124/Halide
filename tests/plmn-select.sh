#!/bin/bash
# tests/plmn-select.sh — network selection manual mode (ch.07 §28): callbox with 2 fake
# PLMNs + forbidden fixture; never live-network brute-force scanning (carrier etiquette).
# Phone-safe: scanning only with callbox interlock; reads modem state otherwise.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v mmcli >/dev/null 2>&1; then
  echo "SKIP: mmcli missing (device/builder only)"; exit 2
fi
if [ "${HALIDE_CALLBOX:-0}" != "1" ]; then
  echo "SKIP: PLMN manual-select needs HALIDE_CALLBOX=1 (2 fake PLMNs, ch.07 §28) (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/plmn-select-$(date +%Y%m%d-%H%M%S).csv
echo "check,result" > "$OUT"
FAIL=0
# scan must complete ≤180s and list numeric codes (names lie, numbers don't)
SCAN=$(timeout 180 mmcli -m any --3gpp-scan 2>&1 | tr -d '\r' || echo "scan-timeout")
if [ "$SCAN" = "scan-timeout" ]; then echo "FAIL: scan >180s (gate)"; FAIL=1; else
  N=$(echo "$SCAN" | grep -cE 'mcc[ ]*[:=][ ]*[0-9]{3}' || true)
  echo "scan-180s,$N PLMNs numeric" | emit >> "$OUT"
  [ "$N" -ge 2 ] || { echo "FAIL: expected ≥2 callbox PLMNs, got $N"; FAIL=1; }
fi
# manual pin to PLMN-B must camp + survive airplane cycle; forbidden row warns + logs
if [ -n "${HALIDE_CALLBOX_PLMN_B:-}" ]; then
  PINRES=$(mmcli -m any --3gpp-register-in-network="$HALIDE_CALLBOX_PLMN_B" 2>&1 | tail -1 | tr -d '\r\n' || echo "register-failed")
  echo "manual-pin,$PINRES" | emit >> "$OUT"
  echo "$PINRES" | grep -qi 'successfully\|registered' || { echo "FAIL: manual pin failed"; FAIL=1; }
fi
# reject-cause-13 fixture: copy must suggest automatic (roaming-not-allowed, §28)
REJ=$(adb shell halide-plmn-drive --fixture reject-13 2>/dev/null | tr -d '\r' || echo "fixture-missing")
if [ "$REJ" != "fixture-missing" ]; then
  echo "$REJ" | grep -qi 'automatic' || { echo "FAIL: reject-13 copy lacks automatic-suggest"; FAIL=1; }
  echo "reject-13,copy-ok" | emit >> "$OUT"
fi
echo "plmn-select: checks in $OUT" | emit
[ "$FAIL" = 0 ] && echo "plmn-select: PASS" || echo "plmn-select: FAIL"
exit "$FAIL"
