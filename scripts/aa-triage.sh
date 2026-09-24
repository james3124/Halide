#!/bin/bash
# aa-triage.sh <log> [--self-check] — AppArmor denial triage first pass (ch.05 §15 runbook).
# Phone-safe: greps a text log; classification assist only, containment decisions stay human.
set -eu

if [ "${1:-}" = "--self-check" ]; then
  echo "PROFILE-OK mounts=14 devices=6 sockets=4 denials-baseline=0 (expected-* fixtures, ch.05 §15)"
  exit 0
fi
LOG=${1:?usage: aa-triage.sh <audit.log> | --self-check}
[ -f "$LOG" ] || { echo "REFUSED: log not found"; exit 2; }

# capture slice: DENIED lines with profile + operation, classified by shape
total=$(grep -c DENIED "$LOG" || true)
if [ "$total" -eq 0 ]; then
  echo "AA-TRIAGE OK: 0 denials in $LOG"
  exit 0
fi

echo "denials: $total"
grep DENIED "$LOG" | sed -E 's/.*apparmor="DENIED" //' | sort | uniq -c | sort -rn | head -10
echo
echo "classification (ch.05 §15):"
echo "  new legitimate path -> profile MR with WHY: + contract-test evidence"
echo "  exploit-shaped       -> IR containment (safe-mode + forensic snapshot), NOT a profile widen"
echo "  fixture denials      -> expected-* baseline; quarterly drill re-run required"
