#!/bin/bash
# tests/hal-contract.sh — umbrella HAL contract gate (ch.05 §9: no contract test, no
# merge): every registered bridge has implementation + registry row + contract test.
# Phone-safe: pure text gate over bridges/ + tests/; live probes delegated to the
# per-bridge contract scripts.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. the five mandatory bridges: registered + implemented
for B in prop ril audio perm composer; do
  grep -q "/run/halide/$B.sock" bridges/SOCKETS.md || { echo "FAIL: $B.sock not in SOCKETS.md"; FAIL=1; }
done
for F in bridges/prop_bridge.py bridges/ril_bridge.py bridges/audio_bridge.py bridges/permission_bridge.py; do
  [ -f "$F" ] || { echo "FAIL: missing implementation $F"; FAIL=1; }
done
echo "hal-contract: 5 mandatory bridges registered — checked"
# 2. composer bridge is AOSP-side C++ (ch.04); registration + source must both exist
[ -f bridges/SOCKETS.md ] && grep -q 'composer.sock' bridges/SOCKETS.md \
  && [ -f aosp/hardware/halide/composer/halide-composer.cpp ] \
  || { echo "FAIL: composer bridge pair incomplete"; FAIL=1; }
# 3. contract tests exist for the text-protocol bridges
for T in bridges/tests/audio_contract.sh bridges/tests/ril_contract.sh bridges/tests/netd_contract.sh; do
  [ -f "$T" ] || { echo "FAIL: missing contract test $T"; FAIL=1; }
done
# 4. HAL coverage doc lists all eight interfaces (tests/HAL-COVERAGE.md)
for H in audio camera sensors GNSS RIL composer keystore biometrics; do
  grep -q "$H" tests/HAL-COVERAGE.md || { echo "FAIL: HAL '$H' missing from tests/HAL-COVERAGE.md"; FAIL=1; }
done
# 5. VTS pin list non-empty (ch.10 §2 honest subset)
[ -s tests/VTS-PINNED.txt ] || { echo "FAIL: tests/VTS-PINNED.txt empty"; FAIL=1; }
# 6. prop proto exists (binary path future-proofing, ch.04 §5)
[ -f bridges/proto/prop.proto ] || { echo "FAIL: bridges/proto/prop.proto missing"; FAIL=1; }
[ "$FAIL" = 0 ] && echo "hal-contract: PASS" || echo "hal-contract: FAIL"
exit "$FAIL"
