#!/bin/bash
# tests/release-compare.sh — release-comparison report skeleton (ch.10 §20).
# Emits the comparison template from committed artifacts; humans add verdicts,
# never numbers. Missing artifacts appear as MISSING-<name> markers (honest gap).
# Phone-safe: reads repo text only.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
PREV="${1:-}"; CURR="${2:-}"
if [ -z "$PREV" ] || [ -z "$CURR" ]; then
  echo "SKIP: usage: release-compare.sh <prev-ver> <curr-ver> (builder text-only)"; exit 2
fi
OUT=qa/compare-${PREV}-to-${CURR}.md
mkdir -p qa
cat > "$OUT" <<EOF
HALIDE $CURR vs $PREV — comparison ($(date +%F), author: TODO)
BUILD: MANIFEST delta (pins changed, lines: TODO) · repro-match: \$(two-builder job) · stage-time deltas: TODO
CTS/VTS: allowlist \$(tests/cts-allowlist.txt pass counts prev → curr) · quarantined \$(tests/quarantine.txt) · newly-green TODO · newly-red TODO
POWER: scenario | prev mA | curr mA | Δ% | verdict — \$(power/<sku>/results.md)
RADIO: attach p50 prev→curr · stall-rate prev→curr · drop % prev→curr · fw change? TODO
PERF: boot prev→curr s · cold-start median prev→curr · jank % prev→curr — \$(logs/boot-timing-*.csv, logs/jank-*)
SOAK: 72h verdict + slope-alert deltas (tests/soak-alerts.conf) · aging notes TODO
DOGFOOD: P0/P1 per 1k device-days prev→curr · worst-thing themes (review-sample.py output)
SECURITY: CVE dispositions delta · patch-lag delta · fuzz MTTR delta
GOLDENS: changed list + MR links · stale-flags cleared/added
VERDICT PER AREA: (Telephony, Power, Perf, Security, QA) — better/same/worse + one-line evidence each
SHIP RECOMMENDATION: (go / hold-for <bug> / needs-extended-soak) + named dissent (ch.10 §16)
EOF
# honesty: mark which evidence artifacts actually exist vs MISSING (§20 rules)
for A in power cts-results qa tests/quarantine.txt tests/soak-alerts.conf manifests/MANIFEST.lock; do
  if [ ! -e "$A" ]; then
    echo "MISSING-$A: no committed artifact — comparison rows stay TODO (never hand-typed)" >> "$OUT"
  fi
done
echo "release-compare: skeleton at $OUT (humans add verdicts; numbers only from artifacts, §20)"
echo "release-compare: PASS"
