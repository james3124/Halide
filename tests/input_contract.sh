#!/bin/bash
# tests/input_contract.sh — input bridge contract (ch.05 §9): coordinates bounded,
# uinput injection single-owner; container cannot touch /dev/input directly.
# Phone-safe: text-level verb matrix + optional live socket probe.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. implementation exists
[ -f bridges/input_bridge.py ] || { echo "FAIL: bridges/input_bridge.py missing"; exit 1; }
# 2. registry: socket documented (ch.05 §10 — undocumented socket = fail)
PY_SOCK=$(grep -o '/run/halide/[a-z.]*\.sock' bridges/input_bridge.py | head -1)
if [ -n "$PY_SOCK" ] && grep -q "$PY_SOCK" bridges/SOCKETS.md; then
  echo "input-contract: $PY_SOCK registered — OK"
else
  echo "FAIL: $PY_SOCK not registered in bridges/SOCKETS.md (registry gap, ch.05 §10)"; FAIL=1
fi
# 3. verb matrix: bounds, bad-key, bad-command per documented protocol
python3 - <<'PY' || FAIL=1
import sys
sys.path.insert(0, "bridges")
import input_bridge
assert input_bridge.handle("TAP 100 200\n") == "OK injected:TAP\n"
assert input_bridge.handle("TAP 5000 10\n") == "ERR bad-coords\n"
assert input_bridge.handle("SWIPE 0 0 100 100\n") == "OK injected:SWIPE\n"
assert input_bridge.handle("KEY 999\n") == "ERR bad-key\n"
assert input_bridge.handle("NOOP\n") == "ERR bad-command\n"
print("input-contract: verb matrix — OK")
PY
# 4. single-owner input: sepolicy must not give untrusted_app /dev/input (ch.04 §14)
if [ -f security/sepolicy-deltas.txt ]; then
  grep -qE '^allow .*input_device' security/sepolicy-deltas.txt \
    && { echo "FAIL: container input_device allow present — dual-master risk"; FAIL=1; } \
    || echo "input-contract: no /dev/input allow in sepolicy deltas — OK"
fi
# 5. live probe (device only): untrusted NOOP must be answered, not hang
if [ -n "$PY_SOCK" ] && [ -S "$PY_SOCK" ]; then
  python3 - <<'PY' || FAIL=1
import socket, sys
s = socket.socket(socket.AF_UNIX); s.settimeout(2)
s.connect("/run/halide/input.sock"); s.sendall(b"NOOP\n")
r = s.recv(64).decode().strip(); s.close(); print("live:", r)
sys.exit(0 if r.startswith("ERR") else 1)
PY
else
  echo "note: no live input socket (device/builder only) — text contract only"
fi
[ "$FAIL" = 0 ] && echo "input-contract: PASS" || echo "input-contract: FAIL"
exit "$FAIL"
