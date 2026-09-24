#!/bin/sh
# firstboot-check.sh -- firstboot slot-health marking hook (runbook-firstboot).
# Lives in hybrid/debian-hooks/. Delegates to halide-firstboot-check so the
# hook stays a thin wiring layer (logic + tests live with the tool).
# Exit contract: 0 marked / 1 check failed / 2 tool missing (skip).
set -eu
if ! command -v halide-firstboot-check >/dev/null 2>&1; then
  echo "SKIP: halide-firstboot-check absent (builder only)"
  exit 2
fi
halide-firstboot-check --stage slot-health
