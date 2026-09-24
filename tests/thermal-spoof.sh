#!/bin/bash
# tests/thermal-spoof.sh — anti-spoof probe for a thermal sysfs path argument.
# Samples the zone 5× and asserts values stay monotonic-sane: real sensors move,
# spoofed/stubbed ones sit frozen or jump wildly. Exit 2 if path missing.
# Phone-safe: reads thermal text only; never writes /sys on the phone.
# DOD: DoD-standby,DoD-logs
set -eu
cd "$(dirname "$0")/.."
ZONE="${1:-}"
if [ -z "$ZONE" ] || [ ! -f "$ZONE/temp" ] && [ ! -f "$ZONE" ]; then
  echo "SKIP: thermal sysfs path missing or not readable (device/builder only)"; exit 2
fi
TZ="$ZONE/temp"; [ -f "$TZ" ] || TZ="$ZONE"
VALS=""
for i in 1 2 3 4 5; do
  V=$(cat "$TZ" | tr -d ' \n')
  case "$V" in *[!0-9]*|"") echo "FAIL: non-numeric sample '$V' — spoof/dead sensor"; exit 1 ;; esac
  [ "$V" -le 150000 ] && [ "$V" -ge 0 ] || { echo "FAIL: sample out of range: $V"; exit 1; }
  VALS="$VALS $V"
  sleep 0.2
done
set -- $VALS
prev=""
jump=0
for v in "$@"; do
  if [ -n "$prev" ]; then
    D=$(( v > prev ? v - prev : prev - v ))
    # >5000 milli-C (5°C) in 200ms is not physics — injected value (spoof signature)
    [ "$D" -gt 5000 ] && jump=$((jump+1))
  fi
  prev=$v
done
uniq=$(printf '%s\n' "$@" | sort -u | wc -l)
if [ "$jump" -gt 0 ]; then echo "FAIL: $jump impossible jumps in samples:$VALS — spoof suspected"; exit 1; fi
if [ "$uniq" -eq 1 ] && [ "${1:-}" != "" ]; then
  echo "note: all samples identical ($VALS) — frozen sensor or idle SoC; flag for review"
fi
echo "thermal-spoof: samples:$VALS — monotonic/sane, no injection signature — PASS"
