#!/bin/bash
# security/sepolicy-comment-lint.sh -- justification-block lint (ch.08 S31 steps 4-6, gates 2-3)
# Every ^allow line must have bug + expiry + test comment in the 5 lines above;
# committed audit2allow output + wildcard allows rejected.
# Usage: sepolicy-comment-lint.sh [--require-bug --require-expiry --require-test] [dir...]
# Exit contract: 0 PASS / 1 FAIL / 2 SKIP-infra. ASCII only.
set -eu
REQ_BUG=0; REQ_EXP=0; REQ_TEST=0
DIRS=""
for a in "$@"; do
  case "$a" in
    --require-bug) REQ_BUG=1 ;;
    --require-expiry) REQ_EXP=1 ;;
    --require-test) REQ_TEST=1 ;;
    *) DIRS="$DIRS $a" ;;
  esac
done
[ -n "$DIRS" ] || DIRS="security device/halide/sepolicy"
FAIL=0
FOUND=0
for D in $DIRS; do
  [ -d "$D" ] || continue
  while IFS= read -r F; do
    [ -z "$F" ] && continue
    FOUND=1
    # gate 2: tool-paste or wildcard allow
    if grep -nE 'audit2allow-generated|allow .* self:capability \*|allow .* \*:.* \*' "$F" >/dev/null 2>&1; then
      echo "FAIL: tool-paste or wildcard allow in $F"
      grep -nE 'audit2allow-generated|allow .* self:capability \*|allow .* \*:.* \*' "$F" | head -5
      FAIL=1
    fi
    # gate 3: justification block above each ^allow (comment lines only, 5-line window)
    LINENO=0
    while IFS= read -r LINE; do
      LINENO=$((LINENO + 1))
      case "$LINE" in allow\ *|allowx\ *) ;;
        *) continue ;;
      esac
      START=$((LINENO - 5)); [ "$START" -lt 1 ] && START=1
      CTX=$(sed -n "${START},$((LINENO - 1))p" "$F" | grep '^#' || true)
      [ "$REQ_BUG" = 1 ] && echo "$CTX" | grep -qi 'BUG' || { echo "FAIL: $F:$LINENO allow without BUG ref"; FAIL=1; }
      [ "$REQ_EXP" = 1 ] && echo "$CTX" | grep -qi 'EXPIRY' || { echo "FAIL: $F:$LINENO allow without EXPIRY"; FAIL=1; }
      [ "$REQ_TEST" = 1 ] && echo "$CTX" | grep -qi 'TEST' || { echo "FAIL: $F:$LINENO allow without TEST"; FAIL=1; }
    done < "$F"
  done <<EOF
$(find "$D" -maxdepth 2 -name '*.te' 2>/dev/null || true)
EOF
done
[ "$FOUND" = 0 ] && echo "note: no .te files under $DIRS (device tree lands with AOSP bring-up)"
[ "$FAIL" = 0 ] && echo "sepolicy-comment-lint: PASS" || echo "sepolicy-comment-lint: FAIL"
exit "$FAIL"
