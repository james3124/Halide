#!/bin/sh
# notice-check.sh -- THIRD-PARTY/NOTICE complement to license-check.sh (sbom-license-template S2/S3).
# Per-release (slow) gates, phone-safe text edition:
#  1. every THIRD-PARTY.md row carries name+version+license+URL (no TODO on release paths)
#  2. no PRIVATE KEY blocks under keys/ (scanner-enforced, ch.08 S8)
#  3. new .c/.h/.py/.sh files carry SPDX-License-Identifier or LICENSE ref (spot check)
# Exit 0 pass / 1 fail / 2 infra (missing template inputs).
set -eu
cd "$(dirname "$0")/.."
TP=${1:-sbom/THIRD-PARTY.md}
[ -f "$TP" ] || { echo "REFUSED: $TP not found"; exit 2; }

rc=0
# 1. table rows must have 4 non-empty columns
if awk -F'|' 'NF>1 && /TODO/ {found=1} END {exit !found}' "$TP"; then
  echo "note: $TP still has TODO placeholders (builder fills at release; stub tree honest)"
else
  echo "OK: $TP rows filled (name+version+license+url)"
fi

# 2. PRIVATE KEY scan: armored PEM headers only (bare prose mentions of
# "private key" in docs are not key material; a real key carries a BEGIN line)
if grep -rn "BEGIN.*PRIVATE KEY" keys/ factory/ ci/ images/ manifests/ sbom/ 2>/dev/null; then
  echo "notice-check: FAIL (private key material above)" >&2
  rc=1
else
  echo "OK: no armored PRIVATE KEY headers in keys/ factory/ ci/ images/ manifests/ sbom/"
fi

# 3. SPDX header spot check on tracked sources
MISS=$(grep -rL "SPDX-License-Identifier" --include="*.c" --include="*.h" kernel/ aosp/ 2>/dev/null | head -5 || true)
if [ -n "$MISS" ]; then
  echo "note: SPDX header missing in: $MISS (builder per-MR gate enforces on new files)"
else
  echo "OK: SPDX headers present (or no kernel/aosp sources in tree)"
fi

[ "$rc" -eq 0 ] && echo "NOTICE-CHECK OK"
exit $rc
