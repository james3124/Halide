#!/bin/bash
# profile-lint.sh — audio policy must parse as JSON (ch.06/S05 audio bridge config hygiene).
# Phone-safe: python3 -m json.tool only. Exit 0 valid / 1 invalid / 2 infra.
set -eu
cd "$(dirname "$0")/.."
P=audio/refa/policy.json
[ -f "$P" ] || { echo "REFUSED: $P not found"; exit 2; }

if python3 -m json.tool "$P" >/dev/null 2>&1; then
  echo "PROFILE-LINT OK: $P parses ($(wc -c < "$P") bytes)"
  exit 0
fi
echo "FAIL: $P is not valid JSON (audio bridge reads this at boot — parse fail = silent fallthrough)"
python3 -m json.tool "$P" || true
exit 1
