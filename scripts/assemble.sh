#!/bin/sh
# assemble.sh — text-only stub (NO COMPILE, no dd on phone).
set -eu
cd "$(dirname "$0")/.."
echo "partition plan: super (system/vendor/product) <=6GiB + host_a/host_b <=2.2GiB each"
echo "slots: A/B for host, super shared; factory image <=11GiB"
echo "builder-only: fastboot flash super + flash host images (see ch.11)"
if [ "${1:-}" = "--plan" ]; then
  echo "assemble: PLAN ONLY (no writes performed)"
  exit 0
fi
echo "refusing to dd on phone: run on builder (--plan to preview)" >&2
exit 2
