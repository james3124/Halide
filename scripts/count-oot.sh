#!/bin/bash
# count-oot.sh — out-of-tree line counter (metric registry D: strictly decreasing, ch.03 S20).
# Phone-safe: wc/grep over kernel fragments and vendor dirs only. Exit 0 ok / 1 grew / 2 infra.
set -eu
cd "$(dirname "$0")/.."

count=0
for f in kernel/*.fragment kernel/devices/* kernel/devices/*/* kernel/vendor_modules/* kernel/vendor_modules/*/*; do
  [ -f "$f" ] || continue
  case "$f" in *.md) continue ;; esac
  # non-comment lines: skip blank and #-prefixed
  n=$(grep -cvE '^[[:space:]]*(#|$)' "$f" || true)
  count=$((count+n))
done

echo "out_of_tree_lines=$count"

HIST=kernel/oot-history.txt
today=$(date -u +%F)
prev=""
if [ -f "$HIST" ]; then
  prev=$(tail -n 1 "$HIST" | awk '{print $2}')
fi
echo "$today $count" >> "$HIST"

if [ -n "$prev" ] && [ "$count" -gt "$prev" ]; then
  echo "FAIL: out_of_tree_lines grew $prev -> $count (registry D: strictly decreasing; upstream first, ch.03 S20)"
  exit 1
fi
exit 0
