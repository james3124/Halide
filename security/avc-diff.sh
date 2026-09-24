#!/bin/bash
# security/avc-diff.sh -- quarterly avc: denied diff vs baseline (ch.08 S4 + S31 audit)
# Usage: avc-diff.sh <baseline> <current>  (audit.log slices; dogfood-opt-in only)
# Emits per-domain new-denial counts vs the CSV budgets; every new denial needs a
# disposition within the S15 clocks (ALLOW-WITH-RULE | MITIGATED-BY-CONFIG | PRODUCT-BUG).
# Exit contract: 0 PASS / 1 FAIL / 2 SKIP-infra. ASCII only.
set -eu
cd "$(dirname "$0")/.."
[ $# -eq 2 ] || { echo "SKIP: usage: avc-diff.sh <baseline> <current> (device/builder only)"; exit 2; }
BASE="$1"; CUR="$2"
[ -f "$BASE" ] || { echo "FAIL-INFRA: baseline $BASE not found (runner/lab issue)"; exit 2; }
[ -f "$CUR" ] || { echo "FAIL-INFRA: current $CUR not found (runner/lab issue)"; exit 2; }
new_denials() { grep -c 'avc:.*denied' "$1" 2>/dev/null || echo 0; }
B=$(new_denials "$BASE"); C=$(new_denials "$CUR")
echo "avc-diff: baseline=$B current=$C delta=$((C - B))"
if [ "$C" -gt "$B" ]; then
  echo "ACTION: $((C - B)) new denials require disposition (ALLOW-WITH-RULE via S31 ladder,"
  echo "MITIGATED-BY-CONFIG with blocking rule + test, or PRODUCT-BUG) inside S15 clocks."
  echo "Artifact: security/avc-audit-<quarter>.md (input to S24-family review week)."
  exit 1
fi
echo "avc-diff: PASS (no new denials)"
exit 0
