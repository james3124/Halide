#!/bin/bash
# scripts/freeze-check.sh -- release-branch freeze tooling (ch.09 S22/S25).
# Validates a cherry-pick queue state file against frozen-branch rules:
# QA sign required, Arch sign for cross-cutting, size <= 300 lines (else
# NEEDS-FULL-RUN), RC budget <= 3, kernel/boot/vbmeta/OTA-verify picks reset
# the bake clock. Phone-safe: text only.
# Usage: freeze-check.sh <picks.tsv>
# TSV columns: pick-id<TAB>size-lines<TAB>qa-sign<TAB>arch-sign<TAB>cross-cutting<TAB>touches-boot
# Signs: yes/no. cross-cutting/touches-boot: yes/no.
# Exit 0 pass / 1 rule violation / 2 usage or missing input.
set -eu
cd "$(dirname "$0")/.."
TSV=${1:?usage: freeze-check.sh <picks.tsv>}
[ -f "$TSV" ] || { echo "REFUSED: $TSV not found"; exit 2; }

rc=0
n=0
while IFS="$(printf '\t')" read -r id size qa arch xcut boot; do
  case "$id" in ''|\#*) continue;; esac
  n=$((n+1))
  case "$size" in *[!0-9]*) echo "FAIL: $id bad size '$size'"; rc=1; continue;; esac
  if [ "$qa" != "yes" ]; then echo "FAIL: $id missing QA sign (no QA sign = no merge)"; rc=1; fi
  if [ "$xcut" = "yes" ] && [ "$arch" != "yes" ]; then
    echo "FAIL: $id cross-cutting without Arch sign"; rc=1
  fi
  if [ "$size" -gt 300 ]; then echo "NOTE: $id $size lines >300 -> NEEDS-FULL-RUN label"; fi
  if [ "$boot" = "yes" ]; then echo "NOTE: $id touches boot chain -> bake clock resets"; fi
done < "$TSV"

if [ "$n" -gt 3 ]; then
  echo "FAIL: $n picks exceed RC respin budget (<=3, 4th triggers Arch split-or-slip review)"
  rc=1
fi
[ "$rc" -eq 0 ] && echo "FREEZE-CHECK OK: $n pick(s) within frozen-branch rules"
exit "$rc"
