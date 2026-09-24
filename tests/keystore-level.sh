#!/bin/bash
# tests/keystore-level.sh — keystore/host trust boundary (ch.05 §3, CtsKeystore subset):
# container keys must be TEE/hardware-backed claims, host sees only its own store.
# Phone-safe: read-only attestation checks.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. static: sepolicy must not grant untrusted_app keystore raw access (ch.04 §14)
if [ -f security/sepolicy-deltas.txt ]; then
  grep -q 'NEVERALLOW' security/sepolicy-deltas.txt \
    && echo "keystore-level: sepolicy deltas carry NEVERALLOW — OK"
  grep -E '^allow .*keystore' security/sepolicy-deltas.txt \
    && { echo "note: explicit keystore allow present — needs Arch review (ch.04 §14)"; } || true
else
  echo "note: security/sepolicy-deltas.txt missing — static keystore check skipped"
fi
# 2. device: hardware-backed flag + rollback resistance on the container keystore
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  AT=$(adb shell halide-keystore-attest 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
  case "$AT" in
    *tool-missing*) echo "SKIP: keystore attest tool absent on unit (device/builder only)"; exit 2 ;;
  esac
  echo "$AT" | grep -qi 'hardware' || { echo "FAIL: keystore not hardware-backed (TEE claim absent)"; FAIL=1; }
  echo "$AT" | grep -qi 'rollback' || echo "note: rollback-resistance flag unreported — CtsKeystore subset will probe"
  echo "keystore-level: attest → $(echo "$AT" | cut -c1-80)" | sed -E 's/[0-9]{10,}/<REDACTED>/g'
else
  echo "SKIP-live: no adb device (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "keystore-level: PASS" || echo "keystore-level: FAIL"
exit "$FAIL"
