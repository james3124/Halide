#!/bin/bash
# kconfig/merge_config.sh — phone-safe wrapper delegating to the kernel tree's merge tool (ch.03 S11).
# Real merge (defconfig + gki.fragment + halide-base + sku) runs on builders only.
# Usage: merge_config.sh [-m] [-O out] <base.config> <frag1> [frag2...]  — or --check for text mode.
set -eu

# NOTE: --check evaluates paths relative to the CALLER's cwd (CI runs from the
# checkout root with hybrid/-prefixed args), so the cd below must not precede it.
if [ "${1:-}" = "--check" ]; then
  shift
  rc=0
  for f in "$@"; do
    if [ -s "$f" ]; then echo "fragment OK: $f ($(grep -cvE '^[[:space:]]*(#|$)' "$f") settings)";
    else echo "FAIL: fragment missing/empty: $f"; rc=1; fi
  done
  echo "merge order reminder: defconfig <- gki.fragment <- halide-base.fragment <- devices/<sku>/sku.fragment"
  exit $rc
fi

cd "$(dirname "$0")/../.."

# find the in-tree tool (builder layout: kernel/linux/scripts/kconfig/merge_config.sh)
for K in kernel/linux scripts/kconfig; do
  if [ -x "$K/scripts/kconfig/merge_config.sh" ]; then exec "$K/scripts/kconfig/merge_config.sh" "$@"; fi
done
if [ -x scripts/kconfig/merge_config.sh ]; then exec scripts/kconfig/merge_config.sh "$@"; fi

echo "REFUSED: no kernel tree with scripts/kconfig/merge_config.sh on this device (NO-COMPILE mode)."
echo "Copy hybrid/ to a builder and run per ch.03 S11; text-mode check: $0 --check <fragments...>"
exit 2
