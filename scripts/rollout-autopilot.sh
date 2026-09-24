#!/bin/bash
# rollout-autopilot.sh <rollout-md> — parse staged rollout % and print next stage or HOLD (ch.09 S20).
# Phone-safe: reads one markdown file; decisions are text rules, telemetry stays on the dashboard.
set -eu
MD=${1:?usage: rollout-autopilot.sh <release/rollout-<ver>.md>}
[ -f "$MD" ] || { echo "REFUSED: $MD not found (autopilot expects release/rollout-<ver>.md per ch.09 S20)"; exit 2; }

# halt conditions first: explicit HOLD/halt marker or rollback-rate over the 2% gate
if grep -qiE '^\s*(HOLD|HALT)\b' "$MD" || grep -qiE 'rollback[_ -]?(rate)?[:= ]+[2-9][0-9]*(\.[0-9]+)?\s*%' "$MD"; then
  reason=$(grep -iE 'HOLD|HALT|rollback' "$MD" | head -n 1 | sed 's/^[[:space:]]*[Hh][AaOo][LlDd][TtDd]:*:[[:space:]]*//')
  echo "HOLD: $reason"
  echo "runbook: freeze stage, pull 5 redacted reports, bisect MANIFEST delta (ch.09 S20)"
  exit 0
fi

# current stage = highest stage marker present (1% -> 10% -> 50% -> 100%)
stage=0
for s in 1 10 50 100; do
  grep -qE "(^|[^0-9])${s}%" "$MD" && stage=$s
done

case "$stage" in
  0)   echo "FAIL: no stage marker (1%/10%/50%/100%) found in $MD"; exit 1 ;;
  100) echo "COMPLETE: 100% reached — publish funnel panel + transparency attestation (ch.09 S17)" ;;
  *)   next=$((stage*10)); [ "$stage" -eq 50 ] && next=100
       echo "NEXT-STAGE: ${next}% (48h bake clock + mix ≥2 SKUs/≥3 carriers must hold, ch.09 S20)" ;;
esac
exit 0
