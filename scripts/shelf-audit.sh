#!/bin/bash
# shelf-audit.sh — spare-parts shelf minimums: 1 spare panel + 1 spare battery per REF (ch.02 S13).
# Phone-safe: text check over hw inventory. Exit 0 stocked / 1 gap / 2 infra.
set -eu
cd "$(dirname "$0")/.."
INV=hw/refa/inventory.md
[ -f "$INV" ] || { echo "REFUSED: $INV not found"; exit 2; }

rc=0
for part in panel battery; do
  if grep -qiE "\|$part" "$INV" || grep -qiE "spare $part|$part \(spare\)|spare-$part" "$INV"; then
    echo "OK: spare $part row present"
  else
    echo "FAIL: no spare $part row in $INV (ch.02 S13: shelf restocked on use, 2-week procurement gap rule)"
    rc=1
  fi
done

[ "$rc" -eq 0 ] && echo "SHELF-AUDIT OK"
exit $rc
