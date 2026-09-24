#!/bin/bash
# sepolicy-comment-lint.sh — sepolicy allowlist hygiene (ch.08 §10 comment-lint).
# Default: no TODO/FIXME/XXX in the normative file. --require-why also demands a WHY-comment
# above every allow line (ch.08 §10 six-step ladder flags, used at release hardening).
# Phone-safe: grep/sed text checks. Exit 0 clean / 1 violation / 2 infra.
set -eu
cd "$(dirname "$0")/.."
F=security/sepolicy-deltas.txt
REQUIRE_WHY=0
[ "${1:-}" = "--require-why" ] && REQUIRE_WHY=1
[ -f "$F" ] || { echo "REFUSED: $F not found"; exit 2; }

rc=0
n=0
while IFS= read -r line; do
  n=$((n+1))
  case "$line" in
    *[Tt][Oo][Dd][Oo]*|*FIXME*|*XXX*)
      echo "FAIL: line $n carries TODO/FIXME/XXX — allowlist is normative, not a scratchpad"
      rc=1 ;;
  esac
  if [ "$REQUIRE_WHY" -eq 1 ]; then
    case "$line" in
      allow\ *|neverallow\ *)
        prev=$(sed -n "$((n-1))p" "$F")
        case "$prev" in
          *WHY:*) : ;;
          *) echo "FAIL: line $n '$line' lacks WHY-comment (ch.08 §10 ladder: bug + expiry + test refs)"; rc=1 ;;
        esac ;;
    esac
  fi
done < "$F"

[ "$rc" -eq 0 ] && echo "SEPOLICY-COMMENT-LINT OK: $F clean (why-required=$REQUIRE_WHY)"
exit $rc
