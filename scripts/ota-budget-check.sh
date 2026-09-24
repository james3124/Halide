#!/bin/bash
# ota-budget-check.sh — OTA payload budget rows must exist before release (ch.09 S27).
# Phone-safe: greps program/BUDGET.md; real byte-count enforcement runs in the builder release job.
set -eu
cd "$(dirname "$0")/.."
B=program/BUDGET.md
[ -f "$B" ] || { echo "REFUSED: $B not found"; exit 2; }

rc=0
for row in "OTA full" "OTA delta" "fleet"; do
  if grep -qi "$row" "$B"; then
    echo "OK: $row budget row present"
  else
    echo "FAIL: no '$row' payload budget row in $B (ch.09 S27: full-cap, delta-cap, 8GB fleet cap)"
    rc=1
  fi
done

# optional per-SKU caps file (builder-side normative numbers)
if [ -d images ] && ls images/*/ota-budget.json >/dev/null 2>&1; then
  for j in images/*/ota-budget.json; do
    python3 -m json.tool "$j" >/dev/null 2>&1 || { echo "FAIL: $j does not parse"; rc=1; }
  done
  echo "ota-budget.json caps: present"
else
  echo "note: images/<sku>/ota-budget.json not present yet (builder fills at assemble)"
fi

[ "$rc" -eq 0 ] && echo "OTA-BUDGET OK"
exit $rc
