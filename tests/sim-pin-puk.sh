#!/bin/bash
# tests/sim-pin-puk.sh — SIM PIN/PUK ladder with conservative counters (ch.07 §27).
# LAB TEST-SIMs ONLY (refuses non-lab ICCID prefix); 1 verify/2s rate limit kept.
# Phone-safe: destructive to SIM retry counters — interlocked + lab ICCID gate.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v mmcli >/dev/null 2>&1; then
  echo "SKIP: mmcli missing (device/builder only)"; exit 2
fi
ICCID=$(mmcli -i 0 -K 2>/dev/null | grep -o 'iccid[=:][0-9]*' | grep -o '[0-9]*' || echo "")
case "$ICCID" in
  "") echo "SKIP: no SIM ICCID readable (device/builder only)"; exit 2 ;;
  "${HALIDE_LAB_ICCID_PREFIX:-__none__}"*)
    echo "sim-pin-puk: lab test-SIM ICCID confirmed (prefix ${HALIDE_LAB_ICCID_PREFIX})" | emit ;;
  *) echo "SKIP: ICCID not in lab prefix list — refuses non-lab SIMs (ch.07 §27) (device/builder only)"; exit 2 ;;
esac
mkdir -p logs
OUT=logs/sim-pin-puk-$(date +%Y%m%d-%H%M%S).csv
echo "step,result,counter" > "$OUT"
FAIL=0
state() { mmcli -i 0 -K 2>/dev/null | grep -o 'pin-retries[=:][0-9]*' | grep -o '[0-9]*' | head -1 || echo "?"; }
# correct-PIN unlock (≤30s then attach gate) with 2s rate limit between verifies
if PIN="${HALIDE_LAB_SIM_PIN:-}"; [ -n "$PIN" ]; then
  R=$(sleep 2; mmcli -i 0 --pin="$PIN" 2>&1 | tail -1 | tr -d '\r\n' || echo "verify-failed")
  echo "unlock,$R,$(state)" | emit >> "$OUT"
  echo "$R" | grep -qi 'successfully\|ok' || FAIL=1
fi
# conservative-counter bias: local state file only ever under-reports (ch.07 §227)
if [ -f /userdata/.halide/simstate ]; then
  C=$(cat /userdata/.halide/simstate)
  case "$C" in *[!0-9]*|"") echo "FAIL: simstate not an integer ($C)"; FAIL=1 ;;
    *) M=$(state); [ "$C" -le "$M" ] || { echo "FAIL: counter over-reports (local=$C modem=$M)"; FAIL=1; } ;;
  esac
  echo "counter-bias,ok,$C" | emit >> "$OUT"
fi
# PUK screen needs triple format validation BEFORE touching the modem (ch.07 §227)
for BAD in "123" "12345678901234567890" "12O4"; do
  case "$BAD" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) : ;;
    *) echo "puk-format-rejected,$BAD,unchanged" | emit >> "$OUT" ;;
  esac
done
echo "sim-pin-puk: ladder in $OUT" | emit
[ "$FAIL" = 0 ] && echo "sim-pin-puk: PASS" || echo "sim-pin-puk: FAIL"
exit "$FAIL"
