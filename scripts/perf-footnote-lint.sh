#!/bin/bash
# perf-footnote-lint.sh — committed perf numbers must carry measurement footnotes (ch.10 §12).
# Phone-safe: grep over power sheets + plan docs. Exit 0 clean / 1 unfootnoted table / 2 infra.
set -eu
cd "$(dirname "$0")/.."
ROOT="$(pwd)"

rc=0
# footnote-set vocabulary per ch.10 §12: unit label, firmware SHAs, ambient, nits, run count,
# calibration, median-vs-mean choice — any md with a perf table must cite at least one
PAT='footnote|calibrat|measurement|median|noise floor|unit label|firmware sha|brightness nits|envelope'
for md in power/*.md power/*/*.md; do
  [ -f "$md" ] || continue
  if grep -qE '^\|.*[0-9]' "$md"; then
    if ! grep -qiE "$PAT" "$md"; then
      echo "FAIL: $md has perf table without footnote set (unit label, firmware SHAs, ambient, nits, runs — ch.10 §12)"
      rc=1
    fi
  fi
done

# plan's power template + bisect runbook must model the footnote discipline
PLAN=""
for d in "$ROOT/hybrid-os-plan" "$ROOT/../hybrid-os-plan"; do
  [ -d "$d" ] && PLAN="$d" && break
done
[ -n "$PLAN" ] || { echo "REFUSED: hybrid-os-plan not found"; exit 2; }
for md in "$PLAN/power-results-template.md" "$PLAN/power-regression-bisect.md"; do
  if [ ! -f "$md" ]; then echo "REFUSED: $md missing (plan docs)"; exit 2; fi
  if ! grep -qiE 'footnote|calibrat|measurement|median' "$md"; then
    echo "FAIL: $md does not mention measurement footnotes (ch.10 §12)"; rc=1
  fi
done

[ "$rc" -eq 0 ] && echo "PERF-FOOTNOTE-LINT OK: power sheets + plan template carry footnote sets"
exit $rc
