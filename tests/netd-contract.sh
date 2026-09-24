#!/bin/bash
# tests/netd-contract.sh — netd→NM contract matrix per ch.05 §16: wifi-up route appears
# ≤3s, host-VPN egress, ndc PERMISSION_DENIED, one portal login, dns-follows, rfkill
# airplane truth. Phone-safe: read-only probes + explicit guard flag for state changes.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. text matrix via the bridge module (contract verbs, runs anywhere)
python3 - <<'PY' || FAIL=1
import sys
sys.path.insert(0, "bridges")
import netd_bridge
assert netd_bridge.handle("UP wlan0\n") == "OK up:wlan0\n"
assert netd_bridge.handle("DOWN eth0\n") == "ERR bad-iface\n"
assert netd_bridge.handle("DNS 8.8.8.8\n") == "OK dns:8.8.8.8\n"
assert netd_bridge.handle("DNS 999.1.1.1\n") == "ERR bad-ip\n"
print("netd-contract: bridge text matrix — OK")
PY
# 2. registry: netd socket documented (ch.05 §10: undocumented socket = fail)
grep -q '/run/halide/netd.sock' bridges/SOCKETS.md \
  && echo "netd-contract: netd.sock registered — OK" \
  || { echo "FAIL: netd.sock not in bridges/SOCKETS.md (registry gap, ch.05 §10)"; FAIL=1; }

# 3. live matrix on device (needs netd drive tool; state-changing steps interlocked)
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  if [ "${HALIDE_NETD_LIVE:-0}" = "1" ]; then
    R=$(adb shell halide-netd-drive --contract-matrix 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
    case "$R" in
      *tool-missing*) echo "SKIP: halide-netd-drive absent on unit (device/builder only)"; exit 2 ;;
      *dns-follows*|*matrix-ok*) echo "netd-contract: live matrix green ($R)" ;;
      *) echo "FAIL: live matrix: $R"; FAIL=1 ;;
    esac
  else
    echo "SKIP-live: set HALIDE_NETD_LIVE=1 for state-changing matrix (device/builder only)"
  fi
else
  echo "SKIP-live: no adb device (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "netd-contract: PASS" || echo "netd-contract: FAIL"
exit "$FAIL"
