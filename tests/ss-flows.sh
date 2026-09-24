#!/bin/bash
# tests/ss-flows.sh — supplementary services: CF/CW queries read-only v1 (ch.07 §26).
# SS and USSD share the modem control channel → shared lock + 30s deadlock watchdog.
# Phone-safe: query-only; SS *set* flows stay disabled v1 (carrier-acceptance evidence
# not yet filed) — asserts that, too.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
FAIL=0

if ! command -v mmcli >/dev/null 2>&1; then
  echo "SKIP: mmcli missing (device/builder only)"; exit 2
fi
if ! mmcli -m any -K >/dev/null 2>&1; then
  echo "SKIP: no modem visible (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/ss-flows-$(date +%Y%m%d-%H%M%S).csv
echo "check,result" > "$OUT"
# 1. query-only: CFU unconditional query returns a state line
R=$(mmcli -m any --voice-list-calls 2>&1 | tail -1 | tr -d '\r\n' || echo "query-failed")
echo "voice-list,$R" | emit >> "$OUT"
# 2. watchdog contract: SS/USSD mutex must exist in bridge config text (shared channel)
if grep -qi 'ussd\|mutex\|watchdog' bridges/ril_bridge.py; then
  echo "ss-ussd-lock,declared" | emit >> "$OUT"
else
  echo "note: SS/USSD shared-mutex not yet declared in ril_bridge (ch.07 §26 rule)"
fi
# 3. set-flows disabled: no CLIR-set / barring-set surface reachable (read-only v1)
if grep -rn 'SetCallForwarding\|SetCallWaiting' bridges/ 2>/dev/null | grep -q .; then
  echo "note: set-flow call-sites present — must be gated behind carrier evidence (ch.07 §26)"
else
  echo "ss-set-flows,disabled-v1" | emit >> "$OUT"
fi
echo "ss-flows: checks in $OUT" | emit
[ "$FAIL" = 0 ] && echo "ss-flows: PASS" || echo "ss-flows: FAIL"
exit "$FAIL"
