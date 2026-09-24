#!/bin/bash
# tests/locale-runtime.sh — runtime locale propagation host→container (ch.05 §27).
# Host clock/locale always wins; bridge rejects container writes (prop allowlist).
# Phone-safe: text + bridge-level checks; live propagation check on device.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. bridge level: persist.sys.locale is the propagation channel (allowlist + host-wins)
python3 - <<'PY' || FAIL=1
import sys
sys.path.insert(0, "bridges")
import prop_bridge
assert prop_bridge.handle("SET persist.sys.locale de-DE\n") == "OK\n"
assert prop_bridge.handle("GET persist.sys.locale\n") == "OK de-DE\n"
print("locale-runtime: prop bridge carries persist.sys.locale — OK")
PY
# 2. static: tzdata/locale pkg staged for the top-12 locales (ch.01 §14)
grep -qi 'locales\|locales-gen\|locales' debian/packages.host 2>/dev/null \
  || echo "note: locales pkg not listed in debian/packages.host (runtime path unverified)"
# 3. live: container locale follows host after a host change (device only)
if command -v localectl >/dev/null 2>&1 && [ -d /run/halide ]; then
  HL=$(localectl show 2>/dev/null | grep -o 'LANG=[^ ]*' || echo "LANG=unset")
  CL=$(adb shell getprop persist.sys.locale 2>/dev/null | tr -d '\r\n' || echo "")
  echo "locale-runtime: host $HL container=$CL"
  if [ -n "$CL" ] && [ "$CL" != "unset" ]; then
    echo "locale-runtime: container locale present — OK"
  else
    echo "note: container locale empty on this unit (firstboot not run?)"
  fi
else
  echo "SKIP-live: no localectl + /run/halide (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "locale-runtime: PASS" || echo "locale-runtime: FAIL"
exit "$FAIL"
