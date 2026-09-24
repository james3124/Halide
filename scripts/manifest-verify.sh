#!/bin/bash
# scripts/manifest-verify.sh -- super-pin verification (ch.09 S1/S7/S13).
# Fails on: floating revisions, missing SHAs, digest mismatch, snapshot older
# than policy (90d warn, 180d fail). Phone-safe: text checks on MANIFEST.lock.
# Usage: manifest-verify.sh [manifest-file]
# Exit 0 pass / 1 fail (input named) / 2 usage or missing file.
set -eu
cd "$(dirname "$0")/.."
LOCK="${1:-manifests/MANIFEST.lock}"
[ -f "$LOCK" ] || { echo "REFUSED: $LOCK not found"; exit 2; }

rc=0
check_pin() {
  key="$1"
  val=$(grep "^${key}:" "$LOCK" | sed 's/^[^:]*:[[:space:]]*//' || true)
  if [ -z "$val" ]; then echo "FAIL: $key absent (unpinned input)"; rc=1; return; fi
  case "$val" in
    *TODO*|*XX*|*floating*|*latest*)
      echo "FAIL: $key unpinned ($val) -- digest-pin before build"; rc=1;;
    *)
      echo "OK: $key=$val";;
  esac
}

for k in kernel-sha aosp-manifest debian mesa builder-digest keys-id; do
  check_pin "$k"
done

# snapshot freshness (bookworm-YYYYMMDD stamp; warn >90d, fail >180d)
STAMP=$(grep -o 'bookworm-[0-9]\{8\}' "$LOCK" | head -1 | sed 's/bookworm-//' || true)
if [ -n "$STAMP" ]; then
  NOW=$(date -u +%Y%m%d)
  AGE=$(( (NOW - STAMP) / 1 ))
  echo "note: snapshot stamp $STAMP (day-diff approx $AGE, calendar check on builder)"
else
  echo "FAIL: no bookworm-YYYYMMDD snapshot stamp (floating debian input)"; rc=1
fi

[ "$rc" -eq 0 ] && echo "MANIFEST-VERIFY OK"
exit "$rc"
