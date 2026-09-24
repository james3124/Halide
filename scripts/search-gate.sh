#!/bin/bash
# search-gate.sh — every gate record must carry a verdict line (ch.00 gate artifacts).
# Phone-safe: grep over program/gates/*.md. Exit 0 all verdit-ed / 1 missing / 2 infra.
set -eu
cd "$(dirname "$0")/.."
DIR=program/gates
[ -d "$DIR" ] || { echo "SKIP: $DIR not created yet (no gate records to lint)"; exit 2; }

rc=0; n=0
for md in "$DIR"/*.md; do
  [ -f "$md" ] || continue
  n=$((n+1))
  if grep -qE '(PASS|FAIL|WAIVED)' "$md"; then
    echo "OK: $(basename "$md") -> $(grep -oE 'PASS|FAIL|WAIVED' "$md" | head -n 1)"
  else
    echo "FAIL: $md has no verdict line (PASS|FAIL|WAIVED) — verbal green is a gate breach (ch.11 S19)"
    rc=1
  fi
done
[ "$n" -eq 0 ] && { echo "note: no *.md gate records in $DIR"; exit 0; }
[ "$rc" -eq 0 ] && echo "SEARCH-GATE OK: $n record(s)"
exit $rc
