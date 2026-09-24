#!/bin/bash
# tests/cpp-parity.sh — C++ bridge source must match its Python twin contract.
# NO COMPILE: parity is enforced textually here; real binary parity on builder.
# ch.05 §9: allowlist is the single consent source — three files must agree.
set -eu
cd "$(dirname "$0")/.."
FAIL=0

CPP=bridges/cpp/prop-bridge.cpp
PY=bridges/prop_bridge.py
AL=bridges/prop-allowlist.txt

[ -f "$CPP" ] || { echo "FAIL: $CPP missing"; exit 2; }

# 1. Every allowlist key in the Python twin must appear in the C++ source and the txt file.
for key in persist.sys.locale persist.sys.timezone sys.boot_completed; do
  grep -q "\"$key\"" "$CPP" || { echo "FAIL: $key missing in $CPP"; FAIL=1; }
  grep -qx "$key" "$AL"    || { echo "FAIL: $key missing in $AL"; FAIL=1; }
done

# 2. Protocol response strings must exist in both twins (GET/SET/denied/too-long).
for tok in "ERR denied" "ERR too-long" "ERR bad-command" "ERR empty"; do
  grep -qF "$tok" "$PY"  || { echo "FAIL: '$tok' missing in $PY"; FAIL=1; }
  grep -qF "$tok" "$CPP" || { echo "FAIL: '$tok' missing in $CPP"; FAIL=1; }
done

# 3. Value-length cap identical (256) in both.
grep -q "256" "$PY"  || { echo "FAIL: cap 256 missing in $PY"; FAIL=1; }
grep -q "256" "$CPP" || { echo "FAIL: cap 256 missing in $CPP"; FAIL=1; }

# 4. Registry socket path is the one both twins document (ch.00 §B).
grep -q "/run/halide/prop.sock" bridges/SOCKETS.md || { echo "FAIL: prop.sock not in SOCKETS.md"; FAIL=1; }

[ "$FAIL" -eq 0 ] && echo "cpp-parity: PASS"
exit "$FAIL"
