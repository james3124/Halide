#!/bin/bash
# build-all.sh — PHONE-SAFE: refuses heavy steps on low-RAM devices.
# Full flow (kernel/AOSP/debian/assemble/sign/OTA) only runs on builders with >=16GB RAM + 400GB free.
# On this phone it runs text-only checks and exits before any OOM risk.
set -eu

MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
AVAIL_DISK_GB=$(df -BG . | awk 'NR==2{gsub("G","",$4); print $4}')

echo "HALIDE build-all (phone-safe)"
echo "Mem total: ${MEM_GB}GB, disk avail: ${AVAIL_DISK_GB}GB"
echo "Manifest: $(cat manifests/MANIFEST.lock 2>/dev/null | head -n 1 || echo MISSING)"

if [ "${1:-check}" = "check" ]; then
  echo "check-only mode: validating text files (safe on phone)"
  test -f manifests/MANIFEST.lock
  test -f kernel/halide-base.fragment
  test -f debian/packages.host
  test -f bridges/SOCKETS.md
  echo "check: OK"
  exit 0
fi

# Any real build target lands here — guard hard.
if [ "$MEM_GB" -lt 16 ]; then
  echo "REFUSED: need >=16GB RAM for '$1' (have ${MEM_GB}GB). Copy hybrid/ to a builder per README.phone-build.md."
  exit 2
fi
if [ "$AVAIL_DISK_GB" -lt 400 ]; then
  echo "REFUSED: need >=400GB free for '$1' (have ${AVAIL_DISK_GB}GB)."
  exit 2
fi

echo "Builder thresholds passed — full flow not implemented in phone skeleton (run on builder)."
exit 0
