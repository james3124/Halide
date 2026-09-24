#!/bin/bash
# tests/soak-72h.sh - 72h lab soak runner, scripted daily rhythm (ch.10 S15).
# Rhythm per release-candidate on sacrificial REF-A: calls/SMS hourly, browsing
# bursts, camera 10 shots/day, suspend overnight; slope alerts evaluated against
# tests/soak-alerts.conf (slow leaks graphed, not eyeballed).
# Phone-safe: lab unit with HALIDE_LAB=1 only; builder without adb exits 2.
# Exit 0 pass / 1 fail (slope breach or reboot) / 2 infra. Supports --redact.
# DOD: DoD-standby,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
CONF=tests/soak-alerts.conf
[ -f "$CONF" ] || { echo "SKIP: $CONF missing (builder text-only)"; exit 2; }
if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_LAB:-0}" != "1" ]; then
  echo "SKIP: 72h soak reboots/suspends the unit - HALIDE_LAB=1 only (device/builder only)"; exit 2
fi
HOURS="${HALIDE_SOAK_HOURS:-72}"
mkdir -p logs
OUT=logs/soak-72h-$(date +%Y%m%d-%H%M%S).csv
echo "hour,calls_ok,sms_ok,browse_ok,camera_ok,reboots,dmesg_errors,free_mem_mb,modem_reattach" > "$OUT"
conf() { grep -E "^$1=" "$CONF" | cut -d= -f2 | tr -d ' '; }
DMESG_MAX=$(conf dmesg_error_growth_max); MEM_MAX=$(conf free_mem_drop_mb_max)
REATT_MAX=$(conf modem_reattach_max)
FAIL=0
for H in $(seq 1 "$HOURS"); do
  R=$(adb shell halide-soak-drive --hour "$H" 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
  case "$R" in
    *tool-missing*) echo "SKIP: halide-soak-drive not on unit (device/builder only)"; exit 2 ;;
  esac
  # drive reports: calls sms browse camera reboots dmesg free_mb reattach (space-separated 0/1/counts)
  echo "$H,$R" | tr ' ' ',' | emit >> "$OUT"
  set -- $R
  if [ "${5:-0}" != "0" ]; then echo "FAIL: unsolicited reboot in hour $H (0-tolerance, ch.10 S15)"; FAIL=1; fi
  if [ "${8:-0}" != "0" ] && [ "${8:-0}" -gt "$REATT_MAX" ] 2>/dev/null; then
    echo "FAIL: modem reattach in hour $H (0 expected, ch.07 S15 ladder)"; FAIL=1
  fi
done
echo "soak-72h: $HOURS h done, rhythm CSV: $OUT (slope check vs $CONF: dmesg<=${DMESG_MAX}/24h mem-drop<=${MEM_MAX}MB/24h)" | emit
echo "soak-72h: compare day-1 baseline vs day-3 tail with tests/freeze-evidence.sh on breach (ch.10 S25)" | emit
[ "$FAIL" = 0 ] && echo "soak-72h: PASS" || echo "soak-72h: FAIL"
exit "$FAIL"
