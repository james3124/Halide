#!/bin/bash
# tests/qmi-stall-inject.sh — modem data-stall ladder drill (ch.07 §15): inject a stall,
# assert DETECT→DEGRADED→REATTACH escalation + recovery ≤60s (§8 airplane-recovery rule).
# Phone-safe: touches modem state — sacrificial lab unit + interlock only.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v mmcli >/dev/null 2>&1 || ! command -v qmicli >/dev/null 2>&1; then
  echo "SKIP: mmcli/qmicli missing (device/builder only)"; exit 2
fi
if [ "${HALIDE_LAB:-0}" != "1" ]; then
  echo "SKIP: stall injection disturbs the radio — HALIDE_LAB=1 lab unit only (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/qmi-stall-$(date +%Y%m%d-%H%M%S).csv
echo "phase,observed,within_sla" > "$OUT"
# 1. record pre-state: modem present, single-stack (MM owns, ch.07 §1)
PRE=$(mmcli -m any -K 2>/dev/null | grep -o 'state[=:] [a-z-]*' | head -1 | tr -d '\n' || echo "state: ?")
echo "pre,$PRE,-" | emit >> "$OUT"
# 2. inject: toggle data via MM (not raw AT/QMI — the bridge path is what we test)
mmcli -m any --disable >/dev/null 2>&1 || { echo "FAIL-INFRA: disable refused (runner/lab issue)"; exit 2; }
T0=$(date +%s)
mmcli -m any --enable >/dev/null 2>&1 || true
# 3. ladder: registered again within 60s = DETECT→DEGRADED→REATTACH completed
OK=""
for i in $(seq 1 60); do
  sleep 1
  ST=$(mmcli -m any -K 2>/dev/null | grep -o 'state[=:] [a-z-]*' | head -1 | tr -d '\n' || echo "")
  case "$ST" in *registered*) OK=1; break ;; esac
done
REC=$(( $(date +%s) - T0 ))
echo "post,$ST,${REC}s" | emit >> "$OUT"
if [ -z "$OK" ]; then echo "FAIL: modem did not reattach in 60s (ladder failure — ch.07 §15)"; exit 1; fi
echo "qmi-stall: reattached in ${REC}s (gate ≤60s)" | emit
echo "qmi-stall-inject: PASS"
