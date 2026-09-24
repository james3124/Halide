#!/bin/bash
# md-links.sh — intra-plan markdown link check (ch.00 doc-CI matrix row 4).
# Phone-safe: reads *.md and stats files only. Exit 0 clean / 1 broken / 2 infra.
set -eu
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLAN_DIR=""
if [ -d "$ROOT/hybrid-os-plan" ]; then PLAN_DIR="$ROOT/hybrid-os-plan";
elif [ -d "$ROOT/../hybrid-os-plan" ]; then PLAN_DIR="$ROOT/../hybrid-os-plan";
else echo "REFUSED: hybrid-os-plan not found"; exit 2; fi

checked=0; broken=0
for md in "$PLAN_DIR"/*.md "$PLAN_DIR"/*/*.md; do
  [ -f "$md" ] || continue
  dir=$(dirname "$md")
  # extract local targets: ](path) — skip http(s), mailto, anchors-only
  for link in $(grep -oE '\]\([^)]+\)' "$md" | sed 's/^\](//; s/)$//'); do
    case "$link" in
      http://*|https://*|mailto:*|\#*) continue ;;
    esac
    target=${link%%#*}            # strip anchor suffix
    case "$target" in
      *.md|*.md/) ;;              # only .md links are verified here
      *) continue ;;
    esac
    checked=$((checked+1))
    # resolve: relative to the linking file's dir, then relative to plan root
    if [ -f "$dir/$target" ] || [ -f "$PLAN_DIR/$target" ]; then continue; fi
    target=${target%/}
    if [ -f "$dir/$target" ] || [ -f "$PLAN_DIR/$target" ]; then continue; fi
    echo "BROKEN: $md -> $link"; broken=$((broken+1))
  done
done

if [ "$broken" -eq 0 ]; then
  echo "MD-LINKS OK: checked=$checked broken=0"
else
  echo "MD-LINKS FAIL: checked=$checked broken=$broken"; exit 1
fi
