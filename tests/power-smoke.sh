#!/bin/bash
# tests/power-smoke.sh - phone-safe power harness, exit 0 pass / 1 fail / 2 infra (ch.10 S7)
set -eu
cd "$(dirname "$0")/.."
FAIL=0
[ -f kernel/halide-base.fragment ] || { echo "FAIL-INFRA missing fragment"; exit 2; }
[ -f debian/packages.host ] || { echo "FAIL-INFRA missing packages.host"; exit 2; }
# 1. zram/memory-pressure note: PSI in fragment (lmkd PSI mode, low-spec S2)
if grep -q 'PSI' kernel/halide-base.fragment; then
  echo "power: PSI note present - OK"
else echo "FAIL: PSI/zram note missing"; FAIL=1; fi
# 2. packages.host cap 20 (same logic as budget-check.sh)
LINES=$(grep -v '^#' debian/packages.host | grep -v '^$' | wc -l)
echo "power: packages.host entries $LINES (cap 20)"
if [ "$LINES" -gt 20 ]; then echo "FAIL: package cap exceeded"; FAIL=1; fi
# 3. panel.json exists (graphics/<sku>/panel.json, ch.06 S11)
if ls graphics/*/panel.json 2>/dev/null | grep -q .; then
  echo "power: panel.json present - OK"
else echo "FAIL: panel.json missing"; FAIL=1; fi
if [ "$FAIL" -eq 0 ]; then echo "power-smoke: PASS"; else echo "power-smoke: FAIL"; fi
exit "$FAIL"
