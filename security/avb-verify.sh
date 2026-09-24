#!/bin/bash
# security/avb-verify.sh -- vbmeta / rollback verification harness (ch.08 S2, 08-A S2/S3, 08-B S2)
# Phone-safe: reads image files or attached dumps only; never flashes, never unlocks.
# Exit contract: 0 PASS / 1 FAIL / 2 SKIP-infra. ASCII only.
set -eu
cd "$(dirname "$0")/.."
FAIL=0
IMG="${1:-}"
ROLLBACK_MIN="${ROLLBACK_MIN:-0}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "SKIP: $1 absent (builder/device only)"; exit 2; }; }

if [ -z "$IMG" ]; then
  # Text-level gate: per-SKU AVB policy files must exist and pin flag/key/rollback refs
  for F in security/avb-policy.txt; do
    [ -f "$F" ] || { echo "FAIL: $F missing"; FAIL=1; }
  done
  grep -q 'rollback-index' security/avb-policy.txt || { echo "FAIL: rollback-index not pinned in avb-policy.txt"; FAIL=1; }
  grep -q 'keys-id' security/avb-policy.txt || { echo "FAIL: release key fingerprint ref missing in avb-policy.txt"; FAIL=1; }
  [ "$FAIL" = 0 ] && echo "avb-verify: PASS (text-level; pass an image path for image-level checks)"
  exit "$FAIL"
fi

need avbtool
[ -f "$IMG" ] || { echo "FAIL-INFRA: image $IMG not found (runner/lab issue)"; exit 2; }
INFO=$(avbtool info_image --image "$IMG" 2>&1) || { echo "FAIL: avbtool could not parse $IMG"; exit 1; }
echo "$INFO" | grep -qi 'flags.*2' || { echo "FAIL: vbmeta flag != 2 (release must be green-enforcing)"; FAIL=1; }
IDX=$(echo "$INFO" | grep -oiE 'rollback_index[^0-9]*[0-9]+' | grep -oE '[0-9]+' | head -1 || echo "")
case "$IDX" in ''|*[!0-9]*) echo "FAIL: rollback index unreadable"; FAIL=1 ;; *)
  [ "$IDX" -ge "$ROLLBACK_MIN" ] || { echo "FAIL: rollback index $IDX < minimum $ROLLBACK_MIN"; FAIL=1; }
  echo "avb-verify: rollback_index=$IDX (min $ROLLBACK_MIN) -- OK" ;;
esac
echo "$INFO" | grep -qi 'testkey' && { echo "FAIL: release image signed by testkey (testkey-never-ships)"; FAIL=1; } || true
[ "$FAIL" = 0 ] && echo "avb-verify: PASS ($IMG)" || echo "avb-verify: FAIL ($IMG)"
exit "$FAIL"
