#!/bin/bash
# tests/gnss-replay.sh — replay a recorded NMEA file through the assertion pipeline
# (ch.10 §17 goldens: golden NMEA + producer pinned together; no device needed).
# Phone-safe: pure text analysis; live injection never runs from a test.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
F="${1:-}"
if [ -z "$F" ]; then
  echo "SKIP: usage: gnss-replay.sh <recorded-nmea-file> (builder text-only)"; exit 2
fi
if [ ! -f "$F" ]; then
  echo "SKIP: NMEA file not found: $F (builder text-only)"; exit 2
fi
RED=0; for a in "$@"; do [ "$a" = "--redact" ] && RED=1; done
REPLAYED=logs/gnss-replay-$(basename "$F").txt
mkdir -p logs
# replay = re-feed the golden log; assert pipeline re-derives the same verdict
if python3 tests/gnss-assert.py "$F" > "$REPLAYED" 2>&1; then
  cat "$REPLAYED"
  echo "gnss-replay: verdict reproduced from $F — PASS"
  exit 0
fi
# assertion failed: with --redact emit the verdict with coordinates scrubbed
if [ "$RED" = 1 ]; then sed -E 's/-?[0-9]{1,3}\.[0-9]{4,}/<COORD>/g; s/[0-9]{10,}/<REDACTED>/g' "$REPLAYED"; else cat "$REPLAYED"; fi
echo "gnss-replay: FAIL (see $REPLAYED)"
exit 1
