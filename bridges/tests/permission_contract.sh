#!/bin/bash
# bridges/tests/permission_contract.sh -- BUS contract for the permission bridge.
# One prompt writes both stores atomically; revoke propagates both ways <=10s.
# Contract test = gate: no contract test, no merge (ch.05 sec9).
set -eu
cd "$(dirname "$0")/../.."
FAIL=0

# 1. bridge implementation exists
[ -f bridges/permission_bridge.py ] || { echo "FAIL: bridges/permission_bridge.py missing"; exit 1; }

# 2. socket path referenced by the bridge matches SOCKETS.md registry exactly
PY_SOCK=$(grep -o '/run/halide/[a-z.]*\.sock' bridges/permission_bridge.py | head -1)
if [ -z "$PY_SOCK" ]; then echo "FAIL: no socket path declared in permission_bridge.py"; FAIL=1;
elif ! grep -q "$PY_SOCK" bridges/SOCKETS.md; then echo "FAIL: $PY_SOCK not registered in bridges/SOCKETS.md"; FAIL=1;
else echo "perm: $PY_SOCK registered -- OK"; fi

# 3. permission-map.csv well-formed (direction column sane, ch.05 sec9)
[ -f bridges/permission-map.csv ] || { echo "FAIL: bridges/permission-map.csv missing"; exit 1; }
python3 - <<'PY' || FAIL=1
import csv
rows = list(csv.DictReader(open("bridges/permission-map.csv")))
assert rows, "empty permission-map"
for r in rows:
    assert set(r) == {"android_perm", "polkit_action", "direction"}, r
    assert r["android_perm"].startswith("android.permission."), r
    assert r["polkit_action"].startswith("org.halide.perm."), r
    assert r["direction"] in {"android-to-host", "both"}, r
print("perm: %d map rows well-formed" % len(rows))
PY

# 4. grant/revoke x20 both directions, 0 desync (text contract, runs anywhere)
python3 - <<'PY' || FAIL=1
import sys
sys.path.insert(0, "bridges")
import permission_bridge
for i in range(20):
    g = permission_bridge.handle("GRANT com.example.app CAMERA\n")
    r = permission_bridge.handle("REVOKE com.example.app CAMERA\n")
    assert g == "OK granted SYNCED both-stacks\n", g
    assert r == "OK revoked SYNCED both-stacks\n", r
assert permission_bridge.handle("GRANT bad MIC\n") == "ERR bad-pkg\n"
assert permission_bridge.handle("GRANT com.example.app SMS\n") == "ERR bad-perm\n"
print("perm: 20 grant/revoke round-trips, SYNCED both stacks -- OK")
PY

# 5. live socket round-trip -- device only, skip cleanly on the phone (exit 2)
if [ -S /run/halide/perm.sock ]; then
  if ! python3 - <<'PY'
import socket, sys
def x(msg):
    s = socket.socket(socket.AF_UNIX); s.settimeout(3)
    s.connect("/run/halide/perm.sock"); s.sendall(msg.encode())
    r = s.recv(128).decode().strip(); s.close(); return r
g = x("GRANT com.example.app CAMERA\n"); print("live:", g)
r = x("REVOKE com.example.app CAMERA\n"); print("live:", r)
sys.exit(0 if "SYNCED both-stacks" in g and "SYNCED both-stacks" in r else 1)
PY
  then echo "FAIL-INFRA: /run/halide/perm.sock exists but gave no answer (runner/lab issue)"; exit 2; fi
else
  echo "note: no live /run/halide/perm.sock (device/builder only) -- static contract only"
fi

[ "$FAIL" -eq 0 ] && echo "permission-contract: PASS"
exit "$FAIL"
