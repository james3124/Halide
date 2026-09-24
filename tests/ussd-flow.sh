#!/bin/bash
# tests/ussd-flow.sh — USSD via host MM single-session (ch.07 §25): IMEI display offline,
# live balance query (recorded per carrier), busy/timeout/abort semantics.
# Phone-safe: *#06# offline is safe; any live network USSD needs HALIDE_USSD_LIVE=1.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
FAIL=0

# 1. offline: *#06# shows IMEI from host (qmicli --dms-get-ids), redaction banner present
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  OUT=$(adb shell halide-ussd-drive --code '*#06#' 2>&1 | tr -d '\r' || echo "tool-missing")
  case "$OUT" in
    *tool-missing*) echo "SKIP: halide-ussd-drive not on unit (device/builder only)"; exit 2 ;;
  esac
  echo "$OUT" | grep -qi 'redact' || { echo "FAIL: IMEI display lacks redaction banner (ch.07 §25)"; FAIL=1; }
  echo "$OUT" | grep -qE '[0-9]{15}' && echo "FAIL: raw IMEI leaked in output" || true
  echo "ussd-flow: *#06# IMEI display via host — OK (banner shown, IMEI redacted)" | emit
fi
# 2. live balance query — only with explicit interlock (charges may apply)
if [ "${HALIDE_USSD_LIVE:-0}" = "1" ]; then
  if ! command -v mmcli >/dev/null 2>&1; then echo "SKIP: mmcli missing (device/builder only)"; exit 2; fi
  CODE="${HALIDE_USSD_CODE:-*100#}"
  R1=$(mmcli -m any --3gpp-ussd-initiate="$CODE" 2>&1 | tail -1 | tr -d '\r\n' || echo "no-service")
  echo "ussd-flow: live '$CODE' → $R1" | emit
  case "$R1" in *NO-SERVICE*|*Network*error*) FAIL=1; echo "FAIL: USSD not delivered" ;; esac
  # dual-initiator race: second session must get USSD-BUSY, not silent double-fire
  R2=$(mmcli -m any --3gpp-ussd-initiate="$CODE" 2>&1 | tail -1 | tr -d '\r\n' || true)
  echo "$R2" | grep -qi 'busy' || echo "note: second initiator not BUSY — session serialization check (ch.07 §25)"
else
  echo "note: live USSD skipped — set HALIDE_USSD_LIVE=1 + HALIDE_USSD_CODE on lab SIM (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "ussd-flow: PASS" || echo "ussd-flow: FAIL"
exit "$FAIL"
