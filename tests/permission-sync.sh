#!/bin/bash
# tests/permission-sync.sh — grant/revoke ×20 both directions, 0 desync (ch.10 §7, ch.05 §9).
# Text level: permission-map.csv well-formed. Live level: perm.sock round-trip.
# Phone-safe: static map check anywhere; live round-trip only with a real socket.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. static: permission-map.csv well-formed, direction column sane (ch.05 §9)
[ -f bridges/permission-map.csv ] || { echo "FAIL: bridges/permission-map.csv missing"; exit 1; }
python3 - <<'PY' || FAIL=1
import csv
rows = list(csv.DictReader(open("bridges/permission-map.csv")))
assert rows, "empty permission-map"
ok_dirs = {"android-to-host", "both"}
for r in rows:
    assert set(r) == {"android_perm", "polkit_action", "direction"}, r
    assert r["android_perm"].startswith("android.permission."), r
    assert r["polkit_action"].startswith("org.halide.perm."), r
    assert r["direction"] in ok_dirs, r
print("perm: %d map rows well-formed" % len(rows))
PY

# 2. bridge-level sync round-trip (text contract, runs anywhere)
python3 - <<'PY' || FAIL=1
import sys
sys.path.insert(0, "bridges")
import permission_bridge
for i in range(20):
    g = permission_bridge.handle("GRANT com.example.app CAMERA\n")
    r = permission_bridge.handle("REVOKE com.example.app CAMERA\n")
    assert g == "OK granted SYNCED both-stacks\n", g
    assert r == "OK revoked SYNCED both-stacks\n", r
print("perm: 20 grant/revoke round-trips, SYNCED both stacks — OK")
PY

# 3. live: real socket on the phone → do one grant/revoke cycle and require SYNCED
if [ -S /run/halide/perm.sock ]; then
  python3 - <<'PY' || FAIL=1
import socket, sys
def x(msg):
    s = socket.socket(socket.AF_UNIX); s.settimeout(3)
    s.connect("/run/halide/perm.sock"); s.sendall(msg.encode())
    r = s.recv(128).decode().strip(); s.close(); return r
g = x("GRANT com.example.app CAMERA\n"); print("live:", g)
r = x("REVOKE com.example.app CAMERA\n"); print("live:", r)
sys.exit(0 if "SYNCED both-stacks" in g and "SYNCED both-stacks" in r else 1)
PY
else
  echo "note: no live /run/halide/perm.sock — text contract only (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "permission-sync: PASS" || echo "permission-sync: FAIL"
exit "$FAIL"
