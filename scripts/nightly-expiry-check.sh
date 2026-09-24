#!/bin/bash
# scripts/nightly-expiry-check.sh -- nightly fossil prevention (ch.09 S12).
# Nightly images embed halide.nightly_expiry=<date+30d>; halide-nightly-watch
# warns at 7-days-left and refuses the Android container past expiry (host
# still boots, radio halted with explanation). Phone-safe: date arithmetic only.
# Usage: nightly-expiry-check.sh <YYYY-MM-DD-expiry> [YYYY-MM-DD-today]
# Exit 0 fresh / 1 expired (refuse container) / 2 usage or bad date.
set -eu
EXP=${1:?usage: nightly-expiry-check.sh <YYYY-MM-DD-expiry> [today]}
TODAY="${2:-$(date -u +%F)}"

days() { date -u -d "$1" +%s 2>/dev/null || { echo "REFUSED: bad date '$1' (want YYYY-MM-DD)"; exit 2; }; }
E=$(days "$EXP"); T=$(days "$TODAY")
LEFT=$(( (E - T) / 86400 ))

if [ "$LEFT" -lt 0 ]; then
  echo "FAIL: nightly expired $((-LEFT)) day(s) ago -- refuse container start, host boots, data exportable"
  exit 1
fi
if [ "$LEFT" -le 7 ]; then
  echo "WARN: nightly expires in $LEFT day(s) -- persistent card: flash release or newer nightly"
  exit 0
fi
echo "NIGHTLY-EXPIRY OK: $LEFT days left"
exit 0
