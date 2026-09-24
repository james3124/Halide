#!/bin/bash
# budget-check.sh — lightweight, phone-safe (KBs of RAM).
# Enforces low-spec-tier-4gb-32gb.md §2/§4 budgets from text files only. No builds.
set -eu
FAIL=0

# 1. packages.host must stay curated (cap lines to catch GNOME creep on phone)
LINES=$(grep -v '^#' debian/packages.host | grep -v '^$' | wc -l)
echo "packages.host entries: $LINES (cap 20 for 4GB tier)"
if [ "$LINES" -gt 20 ]; then echo "FAIL: package list grew, needs Arch sign"; FAIL=1; fi

# 2. kernel fragment must not enable debug hogs on release path
if grep -q 'CONFIG_DEBUG_INFO=y' kernel/halide-base.fragment; then
  echo "FAIL: DEBUG_INFO in base fragment (image-size + RAM cost)"; FAIL=1
else echo "kernel fragment: no DEBUG_INFO — OK"; fi

# 3. SOCKETS.md must list the 5 mandatory bridges
for s in prop.sock ril.sock audio.sock perm.sock composer.sock; do
  grep -q "$s" bridges/SOCKETS.md || { echo "FAIL: missing $s"; FAIL=1; }
done
echo "sockets registry: checked"

# 4. factory image cap reminder (enforced on builder; checked as text here)
echo "storage cap: super <=6GiB + host <=2.2GiB each, factory <=11GiB (builder-enforced)"

if [ "$FAIL" -eq 0 ]; then echo "budget-check: PASS"; else echo "budget-check: FAIL"; fi
exit "$FAIL"
