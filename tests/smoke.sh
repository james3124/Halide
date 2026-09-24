#!/bin/bash
# tests/smoke.sh — harness contract: exit 0 pass / 1 fail / 2 infra issue (ch.10 §7)
set -eu
cd "$(dirname "$0")/.."
./scripts/build-all.sh check
./scripts/budget-check.sh
echo "smoke: PASS"
