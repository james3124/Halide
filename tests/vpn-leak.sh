#!/bin/bash
# tests/vpn-leak.sh — flap VPN 10×, container egress must fail CLOSED every time (ch.10 §7).
# Phone-safe: read-only observation of egress; never reconfigures host network.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
# the probe runs inside the container namespace via the netd bridge path
RES=$(adb shell halide-netd-drive --vpn-flap-test 10 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
case "$RES" in
  *tool-missing*) echo "SKIP: halide-netd-drive not on unit (device/builder only)"; exit 2 ;;
esac
LEAKS=$(echo "$RES" | grep -o 'leaks=[0-9]*' | cut -d= -f2 || echo "?")
FLAPS=$(echo "$RES" | grep -o 'flaps=[0-9]*' | cut -d= -f2 || echo "?")
case "${LEAKS}${FLAPS}" in *[!0-9]*|"") echo "FAIL-INFRA: probe output unparseable (runner/lab issue)"; exit 2 ;; esac
echo "vpn-leak: flaps=$FLAPS leaks=$LEAKS (kill-switch gate: leaks=0)"
[ "$FLAPS" -eq 10 ] || { echo "FAIL-INFRA: probe did not complete 10 flaps (runner/lab issue)"; exit 2; }
[ "$LEAKS" -eq 0 ] || { echo "FAIL: egress leaked $LEAKS times — kill-switch not fail-closed (ch.05 §16)"; FAIL=1; }
# host route integrity too: Android ndc must never mutate host routes (ch.05 §16 matrix)
adb shell halide-netd-drive --ndc-guard-probe 2>&1 | grep -q 'PERMISSION_DENIED' \
  || { echo "FAIL: ndc mutation not denied — single-owner rule broken"; FAIL=1; }
[ "$FAIL" = 0 ] && echo "vpn-leak: PASS" || echo "vpn-leak: FAIL"
exit "$FAIL"
