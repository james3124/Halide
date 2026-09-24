#!/bin/bash
# tests/shutdown-drain.sh — poweroff/reboot/forced-cutoff/OTA-reboot drain matrix (ch.05 §26).
# 20 clean poweroffs (SHUTDOWN-CLEAN + SMS count preserved), 20 reboots (attach ≤90s),
# 5 forced cutoffs, 3 OTA reboots — counts adjustable via env on lab runners.
# Phone-safe: reboot/poweroff driven via adb on lab units, interlocked.
# DOD: DoD-standby,DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_LAB:-0}" != "1" ]; then
  echo "SKIP: drain matrix reboots the unit — HALIDE_LAB=1 only (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/shutdown-drain-$(date +%Y%m%d-%H%M%S).csv
echo "cycle,kind,ok,note" > "$OUT"
FAIL=0
clean_poweroffs="${HALIDE_DRAIN_POFFS:-20}"; reboots="${HALIDE_DRAIN_REBOOTS:-20}"
forced="${HALIDE_DRAIN_FORCED:-5}"; ota="${HALIDE_DRAIN_OTA:-3}"
run_cycle() { # $1 kind, $2 expected marker
  R=$(adb shell halide-drain-drive --"$1" --expect "$2" 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
  case "$R" in
    *tool-missing*) echo "SKIP: halide-drain-drive not on unit (device/builder only)"; exit 2 ;;
  esac
  if echo "$R" | grep -q "$2"; then printf '%s,%s,yes,\n' "$1" "$2" | emit >> "$OUT"
  else printf '%s,%s,no,%s\n' "$1" "$2" "$R" | emit >> "$OUT"; return 1; fi
}
for i in $(seq 1 "$clean_poweroffs"); do run_cycle poweroff SHUTDOWN-CLEAN || FAIL=1; done
for i in $(seq 1 "$reboots"); do run_cycle reboot ATTACH-OK || FAIL=1; done
for i in $(seq 1 "$forced"); do run_cycle forced-cutoff DIRTY-BOOT-CHECK-OK || FAIL=1; done
for i in $(seq 1 "$ota"); do run_cycle ota-reboot RECOUNT-GREEN || FAIL=1; done
echo "shutdown-drain: matrix in $OUT (poffs=$clean_poweroffs reboots=$reboots forced=$forced ota=$ota)" | emit
[ "$FAIL" = 0 ] && echo "shutdown-drain: PASS" || echo "shutdown-drain: FAIL"
exit "$FAIL"
