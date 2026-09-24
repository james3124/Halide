#!/bin/bash
# wc-budget.sh — plan chapter character-budget check (binding, ch.00 File-map table).
# Phone-safe: text-only `wc -m` over plan markdown; no builds, no network, KBs of RAM.
set -eu

# Prelude: resolve plan dir — script lives in <root>/hybrid/scripts, so repo root is two up;
# the plan sits at <root>/hybrid-os-plan (or alongside hybrid/ as ../hybrid-os-plan).
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLAN_DIR=""
if [ -d "$ROOT/hybrid-os-plan" ]; then PLAN_DIR="$ROOT/hybrid-os-plan";
elif [ -d "$ROOT/../hybrid-os-plan" ]; then PLAN_DIR="$ROOT/../hybrid-os-plan";
else echo "REFUSED: hybrid-os-plan not found"; exit 2; fi
cd "$(dirname "$PLAN_DIR")"

# Reference logic (committed verbatim per ch.00 §Doc-change CI):
declare -A B=( [00]=30000 [01]=50000 [02]=50000 [03]=90000 [04]=90000 [05]=80000 \
  [06]=70000 [07]=60000 [08]=70000 [09]=60000 [10]=50000 [11]=40000 )
sum=0; rc=0
for n in 00 01 02 03 04 05 06 07 08 09 10 11; do
  f=hybrid-os-plan/$n-*.md; actual=$(wc -m < $f); budget=${B[$n]}; cap=$((budget*105/100))
  sum=$((sum+actual))
  if [ "$actual" -lt "$budget" ]; then echo "$n: $actual/$budget UNDER"; rc=1
  elif [ "$actual" -gt "$cap" ]; then echo "$n: $actual/$budget OVER-CAP(+5%)"; rc=1
  else echo "$n: $actual/$budget OK"; fi
done
echo "SUM=$sum WINDOW=500000-900000"
[ "$sum" -lt 500000 ] && rc=1; [ "$sum" -gt 900000 ] && rc=1
exit $rc
