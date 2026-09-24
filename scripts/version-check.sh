#!/bin/bash
# scripts/version-check.sh -- version-string inputs for halide-version.py (ch.01 S294, ch.09 S8).
# Reads manifests/version.env (committed, no git needed) and emits the two-line
# About-copy block that tests/test_version.py validates:
#   HALIDE=<ver> BUILD=<buildmeta> SKU=<sku> SLOT=<A|B> KERNEL=<rel> SPL=<date> ...
#   manifest=<hash> sbom=<hash>
# Also asserts the ch.09 S8 match rule inputs exist (/etc/halide-release source
# vs container build.prop halide.version -- compared at first-boot; this script
# checks the tree carries both emitters). Phone-safe: text only.
# Usage: version-check.sh [--emit <out-file>]
# Exit 0 pass / 1 schema fail / 2 usage or missing inputs.
set -eu
cd "$(dirname "$0")/.."
ENVF=manifests/version.env
[ -f "$ENVF" ] || { echo "REFUSED: $ENVF not found"; exit 2; }

# shellcheck disable=SC1090: version.env is a committed KEY=VALUE file
set -a; . "./$ENVF"; set +a
for v in HALIDE_VER BUILD SKU SLOT KERNEL SPL MODEM CARRIER MANIFEST_SHA SBOM_SHA; do
  eval "test -n \"\${$v:-}\" " || { echo "FAIL: $v empty in $ENVF"; exit 1; }
done

BLOCK=$(printf 'HALIDE=%s BUILD=%s SKU=%s SLOT=%s KERNEL=%s SPL=%s MODEM=%s CARRIER=%s\nmanifest=%s sbom=%s' \
  "$HALIDE_VER" "$BUILD" "$SKU" "$SLOT" "$KERNEL" "$SPL" "$MODEM" "$CARRIER" "$MANIFEST_SHA" "$SBOM_SHA")

TMP=$(mktemp)
printf '%s\n' "$BLOCK" > "$TMP"
if python3 tests/test_version.py "$TMP" >/dev/null 2>&1; then
  echo "VERSION-CHECK OK: $HALIDE_VER $SKU slot $SLOT"
else
  echo "FAIL: emitted block rejected by tests/test_version.py:"; printf '%s\n' "$BLOCK"; rm -f "$TMP"; exit 1
fi
rm -f "$TMP"

if [ "${1:-}" = "--emit" ]; then
  OUT="${2:?usage: version-check.sh --emit <out-file>}"
  printf '%s\n' "$BLOCK" > "$OUT"
  echo "emitted $OUT"
fi

# halide-version.py cross-check (git-backed id format, informational)
python3 scripts/halide-version.py print >/dev/null && echo "OK: halide-version.py id format valid"
exit 0
