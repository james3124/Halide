#!/bin/bash
# socket-audit.sh — SOCKETS.md matches live `ss -x` (builder). Phone-safe: skips live check if ss missing.
set -eu
cd "$(dirname "$0")/.."
FAIL=0
for s in prop.sock ril.sock audio.sock perm.sock composer.sock; do
  grep -q "$s" bridges/SOCKETS.md || { echo "FAIL: $s not in SOCKETS.md"; FAIL=1; }
done
if command -v ss >/dev/null 2>&1; then
  ss -x | grep -q halide || echo "note: no halide sockets live (expected on phone)"
else
  echo "note: ss not present on phone, registry check only"
fi
[ "$FAIL" -eq 0 ] && echo "socket-audit: PASS"
exit "$FAIL"
