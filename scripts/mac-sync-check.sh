#!/bin/bash
# mac-sync-check.sh — MAC (address) uniqueness audit over hw inventory (ch.02 §13 lab-kept gear).
# Phone-safe: grep/awk text check. Exit 0 unique / 1 duplicate / 2 infra.
set -eu
cd "$(dirname "$0")/.."
INV=hw/refa/inventory.md
[ -f "$INV" ] || { echo "REFUSED: $INV not found"; exit 2; }

# MAC-like tokens: 6 colon pairs (also handles comma/space separated inventory cells)
mapfile -t macs < <(grep -oiE '([0-9a-f]{2}:){5}[0-9a-f]{2}' "$INV" | tr 'A-F' 'a-f')

if [ "${#macs[@]}" -eq 0 ]; then
  echo "MAC-SYNC OK: 0 addresses recorded (inventory stub — add MACs when gear is labeled, ch.02 §13)"
  exit 0
fi

dups=$(printf '%s\n' "${macs[@]}" | sort | uniq -d)
if [ -n "$dups" ]; then
  echo "FAIL: duplicate MAC address(es):"
  echo "$dups"
  exit 1
fi
echo "MAC-SYNC OK: ${#macs[@]} addresses, all unique"
