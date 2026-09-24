#!/bin/bash
# tests/repro-flake.sh — flake reproduction recording (ch.10 §11 triage runbook):
# run one suite script N times with a seed, record per-run verdicts; any fail on an
# unchanged tree = reproducible flake evidence for the DIG (ch.10 §25).
# Phone-safe: runs only tests/*.sh text suites; never device suites.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
SUITE="${1:-}"
RUNS="${2:-10}"
if [ -z "$SUITE" ]; then
  echo "SKIP: usage: repro-flake.sh <tests/foo.sh> [runs] (builder text-only)"; exit 2
fi
[ -f "$SUITE" ] || { echo "SKIP: suite not found: $SUITE (builder text-only)"; exit 2; }
case "$SUITE" in
  *boot-timing*|*call-loop*|*sms-loop*|*camera-burst*|*gnss-track*|*ota-rollback*|*jank-measure*|*data-soak*)
    echo "SKIP: device/lab suites are not repro-flake targets here (device/builder only)"; exit 2 ;;
esac
mkdir -p logs
RECORD=logs/repro-flake-$(basename "$SUITE" .sh)-seed${SEED:-0}-$(date +%Y%m%d-%H%M%S).log
echo "# repro command: SEED=${SEED:-0} tests/repro-flake.sh $SUITE $RUNS (ch.09 §18 isolate)" > "$RECORD"
PASS=0; FAIL=0; INFRA=0
for i in $(seq 1 "$RUNS"); do
  if SEED="${SEED:-0}" bash "$SUITE" --redact >> "$RECORD" 2>&1; then
    PASS=$((PASS+1)); echo "run $i: PASS" >> "$RECORD"
  else
    RC=$?
    case "$RC" in
      2) INFRA=$((INFRA+1)); echo "run $i: INFRA(2)" >> "$RECORD" ;;
      *) FAIL=$((FAIL+1)); echo "run $i: FAIL(1)" >> "$RECORD" ;;
    esac
  fi
done
RATE=$(python3 -c "print(round(100.0*$FAIL/$RUNS,1))")
echo "repro-flake: $SUITE × $RUNS → pass=$PASS fail=$FAIL infra=$INFRA (fail-rate ${RATE}%)"
# >5% over 50 runs is P1 (ch.10 §6); any fail in a short repro burst is flake evidence
if [ "$FAIL" -gt 0 ]; then echo "FAIL: flake reproduced — file DIG with $RECORD as evidence"; exit 1; fi
echo "repro-flake: PASS (no fail across $RUNS runs; record: $RECORD)"
