#!/bin/sh
# carrier-lint.sh — validate telephony/apn.csv header + >=1 row.
set -eu
cd "$(dirname "$0")/.."
F=telephony/apn.csv
[ -f "$F" ] || { echo "FAIL: $F missing" >&2; exit 1; }
HDR=$(head -n 1 "$F")
[ "$HDR" = "mcc,mnc,carrier,apn" ] || { echo "FAIL: bad header: $HDR" >&2; exit 1; }
ROWS=$(tail -n +2 "$F" | grep -v '^$' | wc -l)
[ "$ROWS" -ge 1 ] || { echo "FAIL: no data rows" >&2; exit 1; }
echo "carrier-lint: PASS ($ROWS rows)"
