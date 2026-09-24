#!/bin/bash
# suspend-stress.sh — 50-cycle suspend/resume with wakeup audit (ch.03 S17 reference code).
# Phone-safe: device/lab-only — needs /sys/kernel/debug/wakeup_sources (debugfs) + rtcwake;
# skips (exit 2) on builder/phone where debugfs is not mounted. Logs land in logs/suspend.txt.
set -eu
cd "$(dirname "$0")/.."

if [ ! -r /sys/kernel/debug/wakeup_sources ]; then
  echo "SKIP: debugfs not mounted (builder/device only)"
  exit 2
fi
command -v rtcwake >/dev/null 2>&1 || { echo "REFUSED: rtcwake not installed (device only)"; exit 2; }

mkdir -p logs
# Reference code (committed verbatim per ch.03 S17):
for i in $(seq 1 50); do
  echo "cycle $i $(date -u +%FT%TZ)" | tee -a logs/suspend.txt
  cat /sys/kernel/debug/wakeup_sources | sort -k7 -n -r | head -5 | tee -a logs/suspend.txt
  rtcwake -m mem -s 10 || echo "RESUME-FAIL cycle $i" | tee -a logs/suspend.txt
  dmesg | tail -20 | tee -a logs/suspend.txt
done
grep -c RESUME-FAIL logs/suspend.txt || echo "0 failures"
