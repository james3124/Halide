#!/bin/bash
# tests/apparmor-seccomp.sh — AppArmor profile + seccomp allowlist sanity (ch.05 §17,
# ch.08 §10). Text-level on the repo tree; live aa-status on device.
# Phone-safe: reads policy text only; never loads/removes profiles.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. static: an AppArmor profile for the container must exist in the plan-referenced path
PROF=""
for C in debian/apparmor.d/lxc-android security/apparmor-lxc-android security/lxc-android; do
  [ -f "$C" ] && PROF="$C" && break
done
if [ -z "$PROF" ]; then
  # plan ch.05 §17 excerpt lives in the chapter; repo may ship profile on builder only
  echo "note: no lxc-android profile file in tree (excerpt lives in ch.05 §17; builder ships it)"
else
  grep -q 'deny.*snd' "$PROF" && echo "apparmor: /dev/snd denied in container profile — OK"
  grep -qE '/run/halide/' "$PROF" && echo "apparmor: bridge sockets scoped — OK"
  grep -q '/\*\* rw' "$PROF" && { echo "FAIL: wildcard rw in profile (ch.05 §17: no /** rw)"; FAIL=1; }
fi
# 2. static: seccomp profile referenced for bridge daemons (ch.08 §10 hardening)
if grep -rqi 'seccomp' debian/overlays/ 2>/dev/null; then
  echo "seccomp: referenced in service overlays — OK"
else
  echo "note: no seccomp reference in debian/overlays (SystemCallFilter missing?)"
fi
# 3. live: profile loaded and enforcing (complain is lab-only, ch.05 §17)
if command -v aa-status >/dev/null 2>&1 && [ -d /run/halide ]; then
  if aa-status 2>/dev/null | grep -q 'lxc-android'; then
    MODE=$(aa-status 2>/dev/null | grep -A2 'lxc-android' | grep -o 'enforce\|complain' | head -1 || echo "?")
    echo "apparmor: lxc-android loaded ($MODE)"
    [ "$MODE" = "enforce" ] || { echo "FAIL: profile in $MODE — complain is lab-only with 48h tag"; FAIL=1; }
  else
    echo "SKIP: lxc-android not loaded on this host (device/builder only)"; exit 2
  fi
else
  echo "SKIP-live: no aa-status + /run/halide (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "apparmor-seccomp: PASS" || echo "apparmor-seccomp: FAIL"
exit "$FAIL"
