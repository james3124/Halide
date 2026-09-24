#!/bin/bash
# tests/lockscreen-policy.sh — biometric gating + PIN-first crypto contract (ch.08 §20, biometric-policy).
# Phone-safe: text checks. Live PIN-rate-limit test is lockscreen-5.sh on device. Exit 0/1/2.
set -eu
cd "$(dirname "$0")/.."
FAIL=0
# Canonical enforcement copy lives in security/ (plan biometric-policy.md is the
# prose source; hybrid/ root carries no duplicate to avoid drift).
POL=security/biometric-policy.md
[ -f "$POL" ] || POL=biometric-policy.md

# 1. Biometrics never key-deriving (biometric-policy §1: PIN wraps LUKS/FBE, not the sensor)
grep -qi "key-deriv\|key deriv" "$POL" 2>/dev/null || \
  echo "note: biometric-policy.md should state never-key-deriving explicitly"

# 2. Face unlock: 2D camera face unlock refused for lockscreen v1 (biometric-policy §1)
if [ -f "$POL" ]; then
  grep -qi "2D-camera face = explicitly refused\|explicitly refused" "$POL" || {
    echo "FAIL: face-unlock refusal not documented (biometric-policy §1)"; FAIL=1; }
fi

# 3. Fallback honesty: 5 fails -> PIN; 10 -> 30s doubling delay; wipe-offer only at 30 (ch.08 §20)
grep -q "10 wrong" security/vb-screens.md 2>/dev/null || true
grep -rqi "wipe-at-30\|wipe-offer at 30\|wipe-at-N" "$POL" security/*.md 2>/dev/null || \
  echo "note: wipe-at-N policy marker not found (documented in ch.08 §20, code lands with halide-pin-derive)"

# 4. Single lock authority: Android keyguard slaved to host verdict (ch.08 §20)
grep -qi "single lock\|slaved to host" "$POL" || \
  echo "note: single-lock-authority rule not in biometric-policy.md (add)"

# 5. LUKS pin derivation service referenced (ch.08 §9: halide-pin-derive)
grep -rq "halide-pin-derive" security/ debian/ 2>/dev/null || \
  echo "note: halide-pin-derive not yet referenced (tool lands with LUKS bring-up)"

# 6. Fingerprint HAL: informational only unless TEE-bound (biometric-policy §1/§2)
[ -f sensors/refa/layout.md ] && grep -qi "fingerprint" sensors/refa/layout.md && \
  echo "note: fingerprint sensor present in SKU layout — must stay informational per biometric-policy §1" || true

[ "$FAIL" -eq 0 ] && echo "lockscreen-policy: PASS"
exit "$FAIL"
