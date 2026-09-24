#!/bin/bash
# scripts/rollback-guard.sh -- rollback protection wiring check (ch.09 S9).
# Asserts the candidate payload rollback-index strictly exceeds the current
# device index (downgrade-block metadata). Phone-safe: pure file comparison.
# Usage: rollback-guard.sh <metadata.json> <current-index-file>
# Exit 0 allowed / 1 blocked (refuse update) / 2 usage or missing inputs.
set -eu
cd "$(dirname "$0")/.."
META=${1:?usage: rollback-guard.sh <metadata.json> <current-index-file>}
CUR=${2:?usage: rollback-guard.sh <metadata.json> <current-index-file>}
[ -f "$META" ] || { echo "REFUSED: $META not found"; exit 2; }
[ -f "$CUR" ] || { echo "REFUSED: $CUR not found"; exit 2; }

python3 - "$META" "$CUR" <<'EOF'
import json,sys
m = json.load(open(sys.argv[1]))
cur = open(sys.argv[2]).read().strip()
try:
    new = int(m["rollback_index"]); old = int(cur)
except (KeyError, ValueError):
    print("FAIL: rollback_index missing or non-integer (device refuses)"); sys.exit(1)
if new > old:
    print("ROLLBACK-GUARD OK: candidate %d > current %d" % (new, old)); sys.exit(0)
print("FAIL: candidate %d <= current %d -- update refused, slot untouched" % (new, old)); sys.exit(1)
EOF
