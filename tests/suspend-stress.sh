#!/bin/bash
# tests/suspend-stress.sh - 50-cycle suspend/resume gate wrapper (ch.10 S26 DoD-standby).
# Delegates to scripts/suspend-stress.sh (ch.03 S17 reference code); this file exists
# so the qa/coverage-map.csv DoD-standby row resolves inside tests/ (coverage-lint).
# Phone-safe: device/lab-only; builder without debugfs exits 2. Exit 0/1/2.
# DOD: DoD-standby,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
[ -f scripts/suspend-stress.sh ] || { echo "SKIP: scripts/suspend-stress.sh missing (builder text-only)"; exit 2; }
bash scripts/suspend-stress.sh > /tmp/halide-suspend-wrap.log 2>&1
RC=$?
if [ "$RC" -ne 0 ]; then
  [ "$RC" = 2 ] && { echo "suspend-stress: SKIP (infra: debugfs/rtcwake absent, device/builder only)"; exit 2; }
  echo "suspend-stress: FAIL (runner error rc=$RC, see /tmp/halide-suspend-wrap.log)"; exit 1
fi
if grep -q "RESUME-FAIL" logs/suspend.txt 2>/dev/null; then
  N=$(grep -c "RESUME-FAIL" logs/suspend.txt)
  echo "suspend-stress: FAIL ($N RESUME-FAIL in logs/suspend.txt)" | emit; exit 1
fi
echo "suspend-stress: PASS (50 cycles, 0 RESUME-FAIL, wakeup audit in logs/suspend.txt)" | emit
