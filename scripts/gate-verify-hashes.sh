#!/bin/bash
# gate-verify-hashes.sh <json> <images-dir> — recompute image SHAs from a gate sidecar.
# Phone-safe: sha256sum only; missing builder artifacts are reported, not fatal-infra lies.
set -eu
JSON=${1:?usage: gate-verify-hashes.sh <json> <images-dir>}; DIR=${2:?usage: gate-verify-hashes.sh <json> <images-dir>}
[ -f "$JSON" ] || { echo "REFUSED: $JSON not found"; exit 2; }
[ -d "$DIR" ] || { echo "REFUSED: images dir $DIR not found"; exit 2; }

# images map: slot -> full sha256 (ch.00 gate-record table)
SLOTS=$(python3 - "$JSON" <<'EOF'
import json,sys
d=json.load(open(sys.argv[1]))
for k,v in d.get("images",{}).items():
    print(k, v)
EOF
)
[ -n "$SLOTS" ] || { echo "FAIL: no images map in $JSON"; exit 1; }

rc=0
while read -r slot want; do
  f="$DIR/$slot.img"
  if [ ! -f "$f" ]; then
    echo "IMAGE-MISSING $slot.img (builder artifact — NO-COMPILE mode on this device)"; exit 2
  fi
  got=$(sha256sum "$f" | cut -c1-8)
  want8=$(echo "$want" | cut -c1-8)
  if [ "$got" = "$want8" ]; then
    echo "HASH-MATCH $slot.img $got"
  else
    echo "FAIL: $slot.img sha $got != recorded $want8"; rc=1
  fi
done <<EOF
$SLOTS
EOF
exit $rc
