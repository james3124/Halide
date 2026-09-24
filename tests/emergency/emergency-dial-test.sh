#!/bin/bash
# tests/emergency/emergency-dial-test.sh — emergency calls route via HOST dialer always
# (ch.07 §1/§10). Regulatory third rail: live e911 only with carrier blessing interlock;
# otherwise assert the routing contract and record UNTESTED per release notes.
# Phone-safe: never auto-dials emergency services.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/../.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
FAIL=0

# 1. routing contract: emergency goes through the host single-stack (MM), never raw
grep -q 'MODEM_OWNER=ModemManager' telephony/mm-config.txt \
  || { echo "FAIL: modem owner not MM — emergency routing contract broken"; FAIL=1; }
grep -q 'STACK=single-stack-only' telephony/mm-config.txt \
  || { echo "FAIL: dual modem stacks present (ch.07 §1)"; FAIL=1; }
echo "emergency-dial: host single-stack ownership — OK" | emit

# 2. per-carrier emergency status must be explicit (VERIFIED-<carrier,date> or UNTESTED bold)
for P in telephony/carrier/*.yaml; do
  [ -f "$P" ] || continue
  E=$(grep -o 'emergency:.*' "$P" | head -1 | tr -d '\r')
  if [ -n "$E" ]; then
    echo "emergency-dial: $P → ${E:-absent}" | emit
    echo "$E" | grep -qE 'emergency: *"(VERIFIED-|UNTESTED)' \
      || { echo "FAIL: $P emergency field not VERIFIED/UNTESTED vocabulary"; FAIL=1; }
  else
    echo "note: $P has no emergency field — defaults to UNTESTED in release notes (never claimed)"
  fi
done

# 3. live dial — ONLY with carrier-blessed interlock + lab target (never real 112/911)
if [ "${HALIDE_EMERGENCY_BLESSED:-0}" = "1" ] && [ -n "${HALIDE_LAB_TARGET:-}" ]; then
  command -v mmcli >/dev/null 2>&1 || { echo "SKIP: mmcli missing (device/builder only)"; exit 2; }
  R=$(mmcli -m any --voice-create-call="number=$HALIDE_LAB_TARGET" 2>&1 | tail -1 | tr -d '\r\n' || echo "create-failed")
  echo "emergency-dial: blessed dial → $R" | emit
  case "$R" in *created*|*queued*) : ;; *) FAIL=1 ;; esac
  mmcli -m any --voice-hangup-all >/dev/null 2>&1 || true
else
  echo "note: live emergency dial skipped — HALIDE_EMERGENCY_BLESSED=1 + lab target only (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "emergency-dial: PASS" || echo "emergency-dial: FAIL"
exit "$FAIL"
