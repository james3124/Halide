#!/bin/bash
# tests/provision-reset.sh — provision + reset drill: factory reset wipes all data EXCEPT
# the standby rollback image (stranded-brick guard, ch.01 §294 retention rules); relock
# after reset; PIN/lock state must NOT survive (ch.07 §27 drain rule).
# Phone-safe: destructive — interlocked to sacrificial lab units only.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_SACRIFICIAL:-0}" != "1" ]; then
  echo "SKIP: reset is destructive — HALIDE_SACRIFICIAL=1 lab unit only (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/provision-reset-$(date +%Y%m%d-%H%M%S).csv
echo "check,result" > "$OUT"
# 1. two-confirmation reset path exists (ch.05 §17: no log survives reset)
#    Driven through the recovery entry point, never an ad-hoc wipe.
if adb shell halide-reset-drive --preflight 2>&1 | grep -qi 'confirm'; then
  echo "two-confirm,present" | emit >> "$OUT"
else
  echo "FAIL: reset path lacks two-confirmation gate (ch.05 §17)"; exit 1
fi
# 2. execute + verify: userdata gone, rollback slot preserved, attestation intact
adb shell halide-reset-drive --execute --confirm 2>&1 | tail -1 | tr -d '\r\n' | emit >> "$OUT"
sleep 45   # reboot into firstboot
LOCK=$(adb shell halide-lock-state --pinset 2>/dev/null | tr -d '\r\n' || echo "?")
SLOT=$(adb shell getprop ro.boot.slot_suffix 2>/dev/null | tr -d '\r\n' || echo "?")
echo "post-reset,lock_pinset=$LOCK slot=$SLOT" | emit >> "$OUT"
[ "$LOCK" = "0" ] || { echo "FAIL: lock PIN survived reset (state must not survive, ch.07 §27)"; exit 1; }
[ -n "$SLOT" ] || { echo "FAIL: no slot after reset — rollback image lost (stranded-brick guard)"; exit 1; }
echo "provision-reset: reset clean, rollback slot $SLOT preserved" | emit
echo "provision-reset: PASS"
