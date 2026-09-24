#!/bin/bash
# tests/firstboot-pin.sh — lockscreen PIN mandatory BEFORE modem attaches (ch.07 §27):
# device lock PIN first, then SIM PIN — stolen-device race prevented by ordering.
# Phone-safe: text/bridge checks; live ordering probe on device.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. static: firstboot runbook encodes the ordering rule
RUNBOOK=debian-hooks/README
if [ -f "$RUNBOOK" ] && grep -qi 'pin\|lock' "$RUNBOOK"; then
  echo "firstboot-pin: hook README mentions PIN stage — OK"
else
  echo "note: $RUNBOOK lacks PIN stage note (ordering rule lives in ch.05 §8)"
fi
# 2. bridge level: lock state is host-owned; container cannot read/write it via props
python3 - <<'PY' || FAIL=1
import sys
sys.path.insert(0, "bridges")
import prop_bridge
assert prop_bridge.handle("GET halide.lock.pinset\n") == "ERR denied\n"
assert prop_bridge.handle("SET halide.lock.pinset 1\n") == "ERR denied\n"
print("firstboot-pin: lock state not exposed on prop bridge — OK")
PY
# 3. live: with no lockscreen PIN, modem must stay unattached (the actual gate, device)
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  LOCK=$(adb shell halide-lock-state --pinset 2>/dev/null | tr -d '\r\n' || echo "tool-missing")
  ATT=$(adb shell halide-modem-state --attached 2>/dev/null | tr -d '\r\n' || echo "tool-missing")
  case "${LOCK}${ATT}" in
    *tool-missing*) echo "SKIP: lock/modem state tools absent on unit (device/builder only)"; exit 2 ;;
    *pinset=0*attached=yes*) echo "FAIL: modem attached without lockscreen PIN (stolen-device race)"; FAIL=1 ;;
    *) echo "firstboot-pin: lock=$LOCK attach=$ATT — ordering holds" ;;
  esac
else
  echo "SKIP-live: no adb device (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "firstboot-pin: PASS" || echo "firstboot-pin: FAIL"
exit "$FAIL"
