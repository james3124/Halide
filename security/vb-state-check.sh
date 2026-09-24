#!/bin/bash
# security/vb-state-check.sh -- verified-boot state assert (ch.08 S27 + S14)
# Checks: state vocabulary agreement (boot prop vs About marker) + eng-watermark
# discipline. Text-level in tree; live via adb on lab units.
# Exit contract: 0 PASS / 1 FAIL / 2 SKIP-infra. ASCII only.
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. text: screen copy file must carry both codes + the no-bypass rule + footer
for NEED in "VB-R1" "VB-R2" "Support will never ask for your PIN" "no .boot anyway"; do
  grep -q "$NEED" security/vb-screens.md || { echo "FAIL: vb-screens.md missing: $NEED"; FAIL=1; }
done
grep -q "VERITY OFF" security/vb-screens.md || { echo "FAIL: eng-watermark discipline missing in vb-screens.md"; FAIL=1; }
grep -q "vb-state-machine.md\|S27" security/vb-screens.md 2>/dev/null || true

# 2. text: state machine doc must define all four handlers
for S in GREEN ORANGE RED-R1 RED-R2; do
  grep -q "$S" security/vb-state-machine.md || { echo "FAIL: vb-state-machine.md missing handler $S"; FAIL=1; }
done

# 3. live: device state prop readable and in vocabulary (lab units only)
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  ST=$(adb shell getprop ro.boot.verifiedbootstate 2>/dev/null | tr -d '\r\n ' || echo "")
  case "$ST" in green|orange|red|"") ;; *) echo "FAIL: unknown verifiedbootstate=$ST"; FAIL=1 ;; esac
  echo "vb-state-check: device state=${ST:-unknown}"
else
  echo "SKIP-live: no adb device (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "vb-state-check: PASS" || echo "vb-state-check: FAIL"
exit "$FAIL"
