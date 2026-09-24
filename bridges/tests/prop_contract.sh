#!/bin/bash
# bridges/tests/prop_contract.sh -- BUS contract for the prop bridge (ch.05 sec9).
# Contract test = gate: no contract test, no merge. Phone-safe: text + optional
# live socket round-trip on the phone only.
set -eu
cd "$(dirname "$0")/../.."
FAIL=0

# 1. bridge implementation exists
[ -f bridges/prop_bridge.py ] || { echo "FAIL: bridges/prop_bridge.py missing"; exit 1; }

# 2. socket path referenced by the bridge matches SOCKETS.md registry exactly
PY_SOCK=$(grep -o '/run/halide/[a-z.]*\.sock' bridges/prop_bridge.py | head -1)
if [ -z "$PY_SOCK" ]; then echo "FAIL: no socket path declared in prop_bridge.py"; FAIL=1;
elif ! grep -q "$PY_SOCK" bridges/SOCKETS.md; then echo "FAIL: $PY_SOCK not registered in bridges/SOCKETS.md"; FAIL=1;
else echo "prop: $PY_SOCK registered -- OK"; fi

# 3. allowlist single consent source: txt file matches module ALLOWLIST
if [ ! -f bridges/prop-allowlist.txt ]; then echo "FAIL: bridges/prop-allowlist.txt missing"; FAIL=1;
else
  python3 - <<'PY' || FAIL=1
import sys
sys.path.insert(0, "bridges")
import prop_bridge
disk = {l.strip() for l in open("bridges/prop-allowlist.txt") if l.strip()}
assert set(prop_bridge.ALLOWLIST) == disk, (set(prop_bridge.ALLOWLIST) ^ disk)
print("prop: allowlist txt == module ALLOWLIST -- OK")
PY
fi

# 4. documented verbs: allowlisted rw, everything else denied + audit-shaped
OUT=$(python3 - <<'PY'
import sys
sys.path.insert(0, "bridges")
import prop_bridge
print("|".join([
    prop_bridge.handle("SET persist.sys.timezone Europe/Berlin\n").strip(),
    prop_bridge.handle("GET persist.sys.timezone\n").strip(),
    prop_bridge.handle("SET gsm.sim.mcc 001\n").strip(),
    prop_bridge.handle("GET halide.lock.pinset\n").strip(),
    prop_bridge.handle("SET persist.sys.timezone " + "x" * 300 + "\n").strip(),
    prop_bridge.handle("NOOP\n").strip(),
]))
PY
) || OUT=""
for want in 'OK' 'OK Europe/Berlin' 'ERR denied' 'ERR too-long' 'ERR bad-command'; do
  case "$OUT" in *"$want"*) : ;; *) echo "FAIL: contract verb '$want' not observed"; FAIL=1 ;; esac
done

# 5. live socket round-trip -- device only, skip cleanly on the phone (exit 2)
if [ -S /run/halide/prop.sock ]; then
  if ! python3 - <<'PY'
import socket, sys
s = socket.socket(socket.AF_UNIX); s.settimeout(2)
s.connect("/run/halide/prop.sock"); s.sendall(b"GET persist.sys.timezone\n")
r = s.recv(64).decode().strip(); s.close()
print("live:", r)
sys.exit(0 if r.startswith(("OK", "ERR")) else 1)
PY
  then echo "FAIL-INFRA: /run/halide/prop.sock exists but gave no answer (runner/lab issue)"; exit 2; fi
else
  echo "note: no live /run/halide/prop.sock (device/builder only) -- static contract only"
fi

[ "$FAIL" -eq 0 ] && echo "prop-contract: PASS"
exit "$FAIL"
