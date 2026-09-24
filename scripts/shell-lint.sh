#!/bin/bash
# scripts/shell-lint.sh -- shell hygiene gate (ch.09 S11 per-MR shellcheck+shfmt).
# Uses shellcheck + shfmt when installed (builder/CI); falls back to bash -n
# syntax check on minimal environments (this phone). ASCII only.
# Exit 0 pass / 1 lint finding / 2 usage or missing tree.
set -eu
cd "$(dirname "$0")/.."
ROOT="${1:-.}"

FILES=$(find "$ROOT/scripts" "$ROOT/ci" "$ROOT/factory" "$ROOT/images" \
  -name "*.sh" -type f 2>/dev/null | sort) || { echo "REFUSED: no script dirs under $ROOT"; exit 2; }
[ -n "$FILES" ] || { echo "REFUSED: no .sh files found"; exit 2; }

rc=0
if command -v shellcheck >/dev/null 2>&1; then
  # shellcheck disable=SC1090,SC1091: sourced files resolve at builder root
  echo "$FILES" | xargs shellcheck -S warning || rc=1
else
  echo "note: shellcheck absent, running bash -n fallback"
  for f in $FILES; do
    bash -n "$f" || { echo "FAIL: syntax $f"; rc=1; }
  done
fi

if command -v shfmt >/dev/null 2>&1; then
  echo "$FILES" | xargs shfmt -d || rc=1
else
  echo "note: shfmt absent, format check skipped (CI enforces)"
fi

[ "$rc" -eq 0 ] && echo "SHELL-LINT OK ($(echo "$FILES" | wc -l) files)"
exit "$rc"
