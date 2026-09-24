#!/bin/bash
# tests/cgroup-pressure.sh — cgroup v2 + PSI sanity for budget tiers (ch.10 §4, ch.03).
# Text-level: kernel fragment + overlay units enable PSI. Device-level: live cgroup tree.
# Phone-safe: reads /sys/cgroup text only; never writes to /sys on the phone.
# DOD: DoD-standby
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. static: PSI enabled in kernel fragment (power-smoke also checks; this asserts cgroup)
if [ -f kernel/halide-base.fragment ]; then
  grep -q 'PSI' kernel/halide-base.fragment \
    || { echo "FAIL: PSI not enabled in kernel/halide-base.fragment (lmkd needs it)"; FAIL=1; }
  echo "cgroup-pressure: fragment PSI — OK"
else
  echo "SKIP: kernel/halide-base.fragment missing (builder only)"; exit 2
fi
# 2. static: composer/daemon units carry memory caps (ch.05 §25 Weight/Max budget)
for U in debian/overlays/halide-android.service debian/overlays/halide-composer.service; do
  [ -f "$U" ] || { echo "SKIP: $U missing (builder only)"; exit 2; }
  grep -qE 'Memory(Max|High)' "$U" || echo "note: $U has no memory cap (check budget table ch.05 §25)"
done
# 3. live: cgroup controllers present + PSI files readable (device only)
if [ -d /sys/fs/cgroup ] && [ -f /sys/fs/cgroup/cgroup.controllers ]; then
  grep -q memory /sys/fs/cgroup/cgroup.controllers || { echo "FAIL: memory controller off"; FAIL=1; }
  if [ -f /proc/pressure/memory ]; then
    VAL=$(grep 'some ' /proc/pressure/memory | awk '{print $2}' | cut -d= -f2)
    echo "cgroup-pressure: PSI memory some.avg10=$VAL (device)"
  else
    echo "note: /proc/pressure/memory absent (PSI compiled off?)"
  fi
else
  echo "SKIP-live: no cgroup v2 tree here (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "cgroup-pressure: PASS" || echo "cgroup-pressure: FAIL"
exit "$FAIL"
