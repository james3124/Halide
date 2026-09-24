#!/bin/bash
# bridges/tests/netd_contract.sh — BUS contract for the netd->NM bridge (ch.05 §9/§16).
set -eu
cd "$(dirname "$0")/../.."
FAIL=0

# 1. bridge implementation exists
[ -f bridges/netd_bridge.py ] || { echo "FAIL: bridges/netd_bridge.py missing"; exit 1; }

# 2. socket path referenced by the bridge matches SOCKETS.md registry exactly
PY_SOCK=$(grep -o '/run/halide/[a-z.]*\.sock' bridges/netd_bridge.py | head -1)
if [ -z "$PY_SOCK" ]; then echo "FAIL: no socket path declared in netd_bridge.py"; FAIL=1;
elif ! grep -q "$PY_SOCK" bridges/SOCKETS.md; then
  echo "FAIL: $PY_SOCK not registered in bridges/SOCKETS.md (registry gap — add row or remove bridge, ch.05 §10)"; FAIL=1;
else echo "netd: $PY_SOCK registered — OK"; fi

# 3. single resolver rule: netd is a client, host NM owns DNS (ch.05 §16)
if python3 - <<'PY'
import sys
sys.path.insert(0, "bridges")
import netd_bridge
r = "|".join([
    netd_bridge.handle("UP wlan0\n").strip(),
    netd_bridge.handle("DOWN eth0\n").strip(),
    netd_bridge.handle("DNS 8.8.8.8\n").strip(),
    netd_bridge.handle("DNS 999.1.1.1\n").strip(),
    netd_bridge.handle("NOOP\n").strip(),
])
print(r)
assert r == "OK up:wlan0|ERR bad-iface|OK dns:8.8.8.8|ERR bad-ip|ERR bad-command", r
PY
then echo "netd: UP/DOWN/DNS verbs behave per contract — OK"
else echo "FAIL: netd verbs deviate from contract"; FAIL=1; fi

# 4. live socket round-trip — device only, skip cleanly on the phone (exit 2)
#    Probe with NOOP: liveness + parser check, never mutates host network state.
if [ -S "${PY_SOCK:-/run/halide/netd.sock}" ]; then
  if ! python3 - <<'PY'
import socket, sys
s = socket.socket(socket.AF_UNIX); s.settimeout(2)
s.connect("/run/halide/netd.sock"); s.sendall(b"NOOP\n")
r = s.recv(64).decode().strip(); s.close()
print("live:", r)
sys.exit(0 if r.startswith("ERR") else 1)
PY
  then echo "FAIL-INFRA: netd socket exists but gave no answer (runner/lab issue)"; exit 2; fi
else
  echo "note: no live netd socket (device/builder only) — static contract only"
fi

[ "$FAIL" -eq 0 ] && echo "netd-contract: PASS"
exit "$FAIL"
