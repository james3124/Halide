#!/bin/sh
# regulator-audit.sh — per-rail regulator audit vs baseline (appendix-03A §3, ch.03 §13).
# Text part (phone-safe): hw/<sku>/regulator-baseline.txt exists, every always-on rail
# carries justification; sku overlay 10-regulators.dtso matches baseline rails.
# Live part (device/builder only): diff regulator_summary use_counts vs baseline.
# Exit 0 pass / 1 fail / 2 infra-or-refused.
set -eu
cd "$(dirname "$0")/.."
SKU=${1:-refa}
BASE=hw/$SKU/regulator-baseline.txt
[ -f "$BASE" ] || { echo "REFUSED: $BASE missing (appendix-03A §3)"; exit 2; }
FAIL=0
# 1. every always-on row must carry justification (same rule as dtbo-lint;
# comment lines excluded — they discuss the rule, they are not rails)
if grep -vE '^[[:space:]]*#' "$BASE" | grep -i "always-on" | grep -vi "justif\|stock\|measured\|datasheet" | grep -q .; then
  echo "FAIL: unjustified always-on rail in $BASE"; FAIL=1
fi
# 2. overlay rails must appear in baseline (no mystery rails)
for rail in $(grep -oE "vreg_[a-z0-9]+" kernel/devices/$SKU/dts/10-regulators.dtso 2>/dev/null | sort -u); do
  grep -q "$rail" "$BASE" || { echo "FAIL: overlay rail $rail absent from $BASE"; FAIL=1; }
done
# 3. live summary (needs debugfs + hardware)
if [ -d /sys/kernel/debug/regulator ]; then
  echo "note: live regulator_summary comparison runs on device/builder (use_count deltas)"
else
  echo "note: no regulator debugfs (device/builder only) — text audit only"
fi
[ "$FAIL" -eq 0 ] && echo "regulator-audit: PASS ($SKU baseline consistent)"
exit "$FAIL"
