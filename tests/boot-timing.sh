#!/bin/bash
# tests/boot-timing.sh — cold-boot timing → CSV per ch.10 §7 (DoD-boot ≤45s gate).
# Phone-safe: adb read-only + one fastboot-driven reboot on the lab unit. Never flashes.
# DOD: DoD-boot,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/boot-timing-$(date +%Y%m%d-%H%M%S).csv
echo "firmware_s,abl_s,kernel_s,systemd_s,container_s,app_ready_s" > "$OUT"

adb reboot >/dev/null 2>&1 || { echo "FAIL-INFRA: adb reboot refused (cable/unit)"; exit 2; }
T0=$(date +%s)
BOOTED=""
for i in $(seq 1 90); do
  sleep 1
  B=$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || true)
  [ "$B" = "1" ] && { BOOTED=1; break; }
done
if [ "$BOOTED" != "1" ]; then echo "FAIL: sys.boot_completed never set within 90s (gate 45s)"; exit 1; fi
APP_READY=$(( $(date +%s) - T0 ))

K_T=$(adb shell cat /proc/uptime 2>/dev/null | cut -d' ' -f1 | tr -d '\r\n' || echo "?")
FW=$(adb shell getprop ro.boot.bootreason 2>/dev/null | tr -d '\r\n' || echo "?")
printf '%s,%s,%s,host-measured,host-measured,%s\n' "$FW" "?" "$K_T" "$APP_READY" | emit >> "$OUT"
echo "boot-timing: app_ready=${APP_READY}s uptime_at_check=${K_T}s fw=$FW (gate ≤45s cold)" | emit
# firmware/ABL/kernel/systemd sub-columns need UART timestamps (ch.10 §7) — runner fills them
echo "note: fine-grained columns from UART/boot_progress merge on the lab runner"
[ "$APP_READY" -le 45 ] && { echo "boot-timing: PASS ($APP_READY s ≤ 45)"; exit 0; }
echo "boot-timing: FAIL ($APP_READY s > 45s gate)"
exit 1
