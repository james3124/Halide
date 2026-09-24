#!/bin/bash
# bake-report.sh — assemble the nightly bake report from logs/*.log (ch.09 S20 bake gates).
# Phone-safe: concatenates text logs into one markdown file; no network, no builds.
set -eu
cd "$(dirname "$0")/.."
mkdir -p logs
OUT="logs/bake-report-$(date -u +%F).md"

{
  echo "# Nightly bake report — $(date -u +%FT%TZ)"
  echo "Manifest: $(head -n 3 manifests/MANIFEST.lock 2>/dev/null | tail -n 1 || echo MISSING)"
  echo "Rollout stage gate reminder: 1%→10%→50%→100% with 48h bake + rollback>2% halts (ch.09 S20)"
  echo
  n=0
  for f in logs/*.log; do
    [ -f "$f" ] || continue
    n=$((n+1))
    echo "## $f ($(wc -l < "$f") lines)"
    echo '```'
    tail -n 30 "$f"
    echo '```'
    echo
  done
  if [ "$n" -eq 0 ]; then
    echo "(no logs/*.log yet — attach harness, suspend, and socket-audit outputs per ch.09 S25)"
  fi
  echo "Bake metrics to fill by hand: nightly_boot_rate, crash-rate delta, rollback-rate (ch.11 S11)"
} > "$OUT"

echo "bake-report: wrote $OUT ($n log section(s))"
exit 0
