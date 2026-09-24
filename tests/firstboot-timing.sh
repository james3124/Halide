#!/bin/bash
# tests/firstboot-timing.sh — first-boot wizard ≤6 min budget (ch.01 §18 launch list,
# runbook-firstboot §3). Text level: budget note; device level: wizard stage timing.
# Phone-safe: timing via boot logs; no wizard interaction.
# DOD: DoD-boot,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
FAIL=0

# 1. static: the 6-minute budget is stated where implementers will see it
if [ -f README.phone-build.md ] && grep -qi 'firstboot\|first boot' README.phone-build.md; then
  echo "firstboot-timing: README covers firstboot — OK"
else
  echo "note: README.phone-build.md silent on firstboot (budget lives in runbook-firstboot §3)"
fi
# 2. device: parse wizard stage timestamps from boot events (fresh firstboot only)
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  T0=$(adb shell halide-firstboot-state --t0-epoch 2>/dev/null | tr -d '\r\n' || echo "tool-missing")
  TD=$(adb shell halide-firstboot-state --done-epoch 2>/dev/null | tr -d '\r\n' || echo "tool-missing")
  case "${T0}${TD}" in
    *tool-missing*|"") echo "SKIP: firstboot state tools absent on unit (device/builder only)"; exit 2 ;;
  esac
  case "${T0}${TD}" in
    *none*|*0*) echo "firstboot-timing: firstboot not yet run on this unit — nothing to measure (device/builder only)"; exit 2 ;;
  esac
  DUR=$(( TD - T0 ))
  echo "firstboot-timing: wizard duration ${DUR}s (budget 360s)" | emit
  [ "$DUR" -le 360 ] || { echo "FAIL: firstboot took ${DUR}s > 360s budget"; FAIL=1; }
else
  echo "SKIP-live: no adb device (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "firstboot-timing: PASS" || echo "firstboot-timing: FAIL"
exit "$FAIL"
