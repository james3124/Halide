#!/bin/bash
# tests/freeze-evidence.sh — snapshot dmesg + wakeup_sources + power tail + SHAs into
# qa/digs/<date>-<trigger>/ on a soak/dogfood trigger (ch.10 §25). 90-day retention.
# Phone-safe: read-only collection; runs on device or against an evidence dir.
# DOD: DoD-standby,DoD-logs
set -eu
cd "$(dirname "$0")/.."
TRIGGER="${1:-unknown-trigger}"
DIR="qa/digs/$(date +%Y%m%d)-$TRIGGER"
mkdir -p "$DIR"

snap() { # $1 label, $2 source command (device or local)
  if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
    adb shell "$2" 2>/dev/null | tr -d '\r' | sed -E 's/[0-9]{10,}/<REDACTED>/g' > "$DIR/$1.txt" || true
  elif eval "$2" >/dev/null 2>&1; then
    eval "$2" 2>/dev/null | sed -E 's/[0-9]{10,}/<REDACTED>/g' > "$DIR/$1.txt" || true
  else
    echo "note: $1 unavailable here" > "$DIR/$1.txt"
  fi
}
snap dmesg-tail "dmesg | tail -200"
snap wakeup-sources "cat /sys/kernel/debug/wakeup_sources"
snap power-tail "tail -100 /run/halide/power-record.csv"
# pstore only exists after a crash-triggered freeze; note when absent
snap pstore "cat /sys/fs/pstore/console-ramoops-0"

{
  echo "trigger: $TRIGGER"
  echo "frozen_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "manifest_sha: $(sha256sum manifests/MANIFEST.lock 2>/dev/null | cut -c1-16 || echo n/a)"
  echo "retention_days: 90"
  echo "next: open qa/digs/$(basename "$DIR")/DIG.md per ch.10 §25 (hypotheses need disproving tests)"
} > "$DIR/FREEZE.json"
echo "freeze-evidence: evidence frozen in $DIR (exit 0; dig template is the next step)"
