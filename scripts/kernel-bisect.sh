#!/bin/sh
# kernel-bisect.sh — stub: MANIFEST-delta bisect steps, no build on phone.
set -eu
cd "$(dirname "$0")/.."
echo "bisect: 1) pin MANIFEST good/bad 2) diff deltas 3) halve commits"
echo "bisect: 4) builder builds + boots 5) mark good/bad, repeat"
echo "bisect: phone does text-only pin/diff (--plan); builds on builder"
if [ "${1:-}" = "--plan" ]; then
  echo "kernel-bisect: PLAN ONLY (no builds performed)"
  exit 0
fi
echo "refusing to build on phone: rerun with --plan" >&2
exit 2
