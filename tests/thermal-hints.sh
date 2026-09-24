#!/bin/bash
# tests/thermal-hints.sh — thermal sysfs sanity vs trip points (ch.10 §28, thermal/refa).
# Reads a thermal sysfs path argument (millidegrees C), asserts values sane and the
# configured trip ladder is monotonic. Exit 2 if path missing.
# Phone-safe: reads thermal text only; never writes /sys on the phone.
# DOD: DoD-standby,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
FAIL=0

# 1. static: trip ladder must be strictly increasing (warn < throttle < shutdown)
CONF=thermal/refa/trip-points.conf
[ -f "$CONF" ] || { echo "SKIP: thermal/refa/trip-points.conf missing (builder only)"; exit 2; }
W=$(grep -o 'skin_warn=[0-9]*' "$CONF" | cut -d= -f2)
T=$(grep -o 'skin_throttle=[0-9]*' "$CONF" | cut -d= -f2)
S=$(grep -o 'skin_shutdown=[0-9]*' "$CONF" | cut -d= -f2)
if [ -n "${W}${T}${S}" ] && [ "$W" -lt "$T" ] && [ "$T" -lt "$S" ]; then
  echo "thermal-hints: trip ladder ${W}C < ${T}C < ${S}C — OK"
else
  echo "FAIL: trip ladder not monotonic (warn=$W throttle=$T shutdown=$S)"; FAIL=1
fi

# 2. live: sysfs path argument must exist and hold sane millidegrees values
ZONE="${1:-}"
if [ -n "$ZONE" ] && [ -d "$ZONE" ]; then
  for V in "$ZONE"/temp*; do
    [ -f "$V" ] || continue
    M=$(cat "$V" | tr -d ' \n')
    echo "thermal-hints: $V = $M milli-C" | emit
    case "$M" in
      *[!0-9]*|"") echo "FAIL: non-numeric temp in $V (spoof or dead sensor)"; FAIL=1 ;;
      *) [ "$M" -le 150000 ] && [ "$M" -ge 0 ] || { echo "FAIL: temp out of range in $V"; FAIL=1; } ;;
    esac
  done
else
  echo "SKIP-live: thermal sysfs path missing (pass e.g. /sys/class/thermal/thermal_zone0) (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "thermal-hints: PASS" || echo "thermal-hints: FAIL"
exit "$FAIL"
