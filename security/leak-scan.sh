#!/bin/bash
# security/leak-scan.sh -- private-key material scanner (ch.08 S8, signer-spec.md)
# CI fails the build if a private-key PEM block is detected in keys/ or security/.
# This script CONTAINS the search string as a grep pattern (that is its job);
# it never contains key material itself. Exit contract: 0 PASS / 1 FAIL / 2 SKIP.
set -eu
cd "$(dirname "$0")/.."
FAIL=0
for D in keys security; do
  [ -d "$D" ] || continue
  # NOTE: the pattern below matches PEM block headers only (plan wording: CI fails
# on a private-key PEM BLOCK). Bare prose mentions of the rule must not trip it.
  if grep -rn --exclude='leak-scan.sh' --exclude-dir='.git' -- '-----BEGIN .*PRIVATE KEY-----' "$D" 2>/dev/null; then
    echo "FAIL: private-key block in $D/ (pubs + metadata ONLY -- see keys/signer-spec.md)"
    FAIL=1
  fi
  if find "$D" -name '*.key' -o -name '*_private*' -o -name '*.p12' -o -name '*.pfx' 2>/dev/null | grep -q .; then
    echo "FAIL: private-key filename in $D/"
    find "$D" \( -name '*.key' -o -name '*_private*' -o -name '*.p12' -o -name '*.pfx' \) 2>/dev/null
    FAIL=1
  fi
done
[ "$FAIL" = 0 ] && echo "leak-scan: PASS (no private-key material)" || echo "leak-scan: FAIL"
exit "$FAIL"
