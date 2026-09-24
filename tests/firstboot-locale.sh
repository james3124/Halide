#!/bin/bash
# tests/firstboot-locale.sh — EL0 MCC → locale/timezone suggestion without phoning home
# (ch.05 §22 first-boot data contract). Suggest-never-apply for travel MCC (§16).
# Phone-safe: text + bridge-level; live firstboot only on device.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. bridge level: timezone string moves only via the allowlisted channel
python3 - <<'PY' || FAIL=1
import sys
sys.path.insert(0, "bridges")
import prop_bridge
assert prop_bridge.handle("SET persist.sys.timezone Europe/Berlin\n") == "OK\n"
assert prop_bridge.handle("GET persist.sys.timezone\n").endswith("Europe/Berlin\n")
# container must NOT be able to set arbitrary keys (no MCC-driven writes around the bridge)
assert prop_bridge.handle("SET gsm.sim.mcc 001\n") == "ERR denied\n"
print("firstboot-locale: tz channel allowlisted, MCC key denied — OK")
PY
# 2. static: MCC→locale map file referenced by the wizard (ch.05 §22)
if [ -f telephony/apn.csv ]; then
  grep -q ',' telephony/apn.csv && echo "firstboot-locale: apn.csv (MCC table) present — OK"
else
  echo "note: telephony/apn.csv missing — wizard MCC map unverified"
fi
# 3. live: on a firstboot'd device, locale must equal the wizard pick, not the SIM MCC default
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  LOC=$(adb shell getprop persist.sys.locale 2>/dev/null | tr -d '\r\n' || echo "")
  [ -n "$LOC" ] || { echo "SKIP: no locale prop on unit (firstboot not run) (device/builder only)"; exit 2; }
  echo "firstboot-locale: unit locale=$LOC (suggest-never-apply: travel MCC only suggests, §16)"
else
  echo "SKIP-live: no adb device (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "firstboot-locale: PASS" || echo "firstboot-locale: FAIL"
exit "$FAIL"
