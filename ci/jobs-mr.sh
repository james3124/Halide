#!/bin/bash
# ci/jobs-mr.sh - per-MR suite (phone-safe)
set -eu
cd "$(dirname "$0")/.."
sh tests/smoke.sh
python3 tests/test_bridges.py
sh scripts/budget-check.sh
sh scripts/socket-audit.sh
sh tests/power-smoke.sh
echo "jobs-mr: PASS"
