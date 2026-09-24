#!/bin/bash
# tests/ota-rollback-test.sh — flash bad slot → assert auto-rollback + report exists (ch.10 §7).
# SACRIFICIAL UNIT ONLY: reflashes slots; interlocked behind HALIDE_SACRIFICIAL=1.
# Phone-safe: guarded destructive op, never runs without the explicit interlock.
# DOD: DoD-OTA,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v fastboot >/dev/null 2>&1 || ! fastboot devices >/dev/null 2>&1; then
  echo "SKIP: no fastboot device (device/builder only)"; exit 2
fi
if [ "${HALIDE_SACRIFICIAL:-0}" != "1" ]; then
  echo "SKIP: slot flash needs HALIDE_SACRIFICIAL=1 (sacrificial lab unit only) (device/builder only)"; exit 2
fi
SN=$(fastboot devices | awk '{print $1}' | head -1)
[ -n "$SN" ] || { echo "FAIL-INFRA: fastboot serial empty (runner/lab issue)"; exit 2; }

# 1. boot the BAD slot: corrupted boot image is pushed from the builder, never made here
if [ ! -f images/bad-slot-test.img ]; then
  echo "SKIP: images/bad-slot-test.img missing on runner (device/builder only)"; exit 2
fi
echo "ota-rollback: flashing known-bad slot boot_b on $SN (sacrificial)"
fastboot flash boot_b images/bad-slot-test.img >/dev/null 2>&1 \
  || { echo "FAIL-INFRA: flash refused (cable/unit state)"; exit 2; }

# 2. assert auto-rollback: device must come back on slot A within the health-gate budget
sleep 60
SLOT=$(adb shell getprop ro.boot.slot_suffix 2>/dev/null | tr -d '\r\n' || echo "?")
BOOTED=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || echo "0")
echo "ota-rollback: slot=$SLOT booted=$BOOTED" | emit
[ "$SLOT" = "_a" ] && [ "$BOOTED" = "1" ] || { echo "FAIL: no auto-rollback (slot=$SLOT booted=$BOOTED)"; exit 1; }

# 3. rollback report must exist and name the event (ch.09 §4 report)
adb shell halide-ota-report --last 2>/dev/null | tr -d '\r' | grep -q 'ROLLBACK' \
  || { echo "FAIL: rollback report missing"; exit 1; }
echo "ota-rollback: auto-rollback + report verified (unit $SN)" | emit
echo "ota-rollback: PASS"
