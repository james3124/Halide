#!/bin/bash
# scripts/hotfix-lane.sh -- hotfix lane 24h clock tracker (ch.09 S21).
# Entry: security PATCH-NOW, rollout-halt fix, or dogfood-P0 fleet-wide.
# Scope discipline: features/perf/non-exploitable hardening ride the train.
# Usage: hotfix-lane.sh <cve-or-p0-id>            (print the 24h clock plan)
#        hotfix-lane.sh check <milestone-log>     (validate T+ milestones present)
# Phone-safe: text only. Exit 0 pass / 1 milestone miss / 2 usage.
set -eu
cd "$(dirname "$0")/.."

if [ "${1:-}" = "check" ]; then
  LOG="${2:?usage: hotfix-lane.sh check <milestone-log>}"
  [ -f "$LOG" ] || { echo "REFUSED: $LOG not found"; exit 2; }
  rc=0
  for m in "T+0" "T+4h" "T+8h" "T+12h" "T+16h" "T+24h"; do
    grep -qF "$m" "$LOG" || { echo "FAIL: milestone $m missing (binding clock)"; rc=1; }
  done
  grep -qi "ceremony" "$LOG" || { echo "FAIL: T+12h expedited ceremony evidence missing (expedited never means abbreviated)"; rc=1; }
  [ "$rc" -eq 0 ] && echo "HOTFIX-CLOCK OK"
  exit "$rc"
fi

ID=${1:?usage: hotfix-lane.sh <cve-or-p0-id>}
cat <<EOF
hotfix lane $ID -- 24h clock (binding, owner + clock logged at T+0)
 T+0  decision logged (hotfix vs train, owner, CVE/bug id)
 T+4h candidate built + CI subset green (two-builder spot-check on affected images)
 T+8h hardware smoke + sign-off deltas (gates-affected evidence only, exceptions explicit)
 T+12h signing ceremony expedited (both custodians, same verbal checks -- overrun escalates to Arch)
 T+16h staged restart at 1 pct (fresh bake clock, same dashboard)
 T+24h go/no-go for 10 pct (rollback-rate + crash-delta reviewed)
branch: cut from exact shipped tag, cherry-picks only (<=300 lines preferred),
  each with QA sign + Arch sign; hotfix uses release-branch cache only.
drill: quarterly synthetic P0 on staging, scored, report release/hotfix-drill-<date>.md
EOF
exit 0
