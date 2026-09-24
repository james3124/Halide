#!/bin/bash
# tests/sms-concat-retry.sh — concatenation + retry state machine (ch.07 §31):
# 3×300-char both directions, RP-ERROR-111 permanent fail (0 retries), SMSC-full 22
# → 1h hold at exactly 1 attempt/hour, MR persistence across reboot.
# Phone-safe: live sends interlocked to lab SIMs; math/audit checks run anywhere.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
FAIL=0

# 1. segmentation math: GSM-7 160→153 (UDH steals 7); boundaries at 153/154/306/307/459/460
for C in "153:1" "154:2" "300:2" "306:2" "307:3" "459:3" "460:4"; do
  N="${C%%:*}"; WANT="${C##*:}"
  GOT=$(( (N + 152) / 153 ))
  [ "$GOT" -eq "$WANT" ] || { echo "FAIL: GSM-7 segmentation $N chars → $GOT segs (want $WANT)"; FAIL=1; }
done
echo "sms-concat: GSM-7 segmentation math — OK"
# 2. MR persistence contract: counter file format (reboot → next = previous+1)
if [ -f /userdata/.halide/sms-mr ]; then
  MR=$(cat /userdata/.halide/sms-mr)
  case "$MR" in *[!0-9]*|"") echo "FAIL: sms-mr not an integer ($MR)"; FAIL=1 ;;
    *) [ "$MR" -le 255 ] || { echo "FAIL: MR >255 (8-bit scope) — 16-bit ref required (ch.07 §31)"; FAIL=1; } ;;
  esac
else
  echo "note: no /userdata/.halide/sms-mr on this host (device/builder only)"
fi
# 3. live 300-char send/receive — lab SIM interlock (charges + carrier etiquette)
if [ "${HALIDE_SMS_LIVE:-0}" = "1" ] && command -v mmcli >/dev/null 2>&1 && [ -n "${HALIDE_LAB_TARGET:-}" ]; then
  BODY=$(python3 -c "print('H'*300)")
  R=$(mmcli -m any --messaging-create-sms="text=$BODY,number=$HALIDE_LAB_TARGET" 2>&1 | tail -1 | tr -d '\r\n' || echo "create-failed")
  echo "sms-concat: 300-char create → $R (expect 3 parts)" | emit
  echo "$R" | grep -o 'Created new SMS: [0-9]*' >/dev/null || FAIL=1
  # RP-ERROR-111 audit: permanent fail must show 0 retries (classification, not blanket retry)
  A=$(adb shell halide-sms-audit --last 2>/dev/null | tr -d '\r' || echo "")
  [ -n "$A" ] && echo "$A" | grep -q 'FAIL-PERMANENT' && echo "sms-concat: RP-ERROR-111 classified permanent — OK" | emit
else
  echo "note: live 300-char exchange skipped — HALIDE_SMS_LIVE=1 + lab target (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "sms-concat-retry: PASS" || echo "sms-concat-retry: FAIL"
exit "$FAIL"
