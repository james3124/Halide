#!/bin/sh
# license-check.sh — phone-safe stub (text only).
# Fails if any .py/.sh contains the license TODO marker.
set -eu
PAT="TODO-lic"
PAT="${PAT}ense"
if grep -rn "$PAT" --include="*.py" --include="*.sh" .; then
  echo "license-check: FAIL (marker found above)" >&2
  exit 1
fi
echo "license-check: PASS (no marker in .py/.sh)"
