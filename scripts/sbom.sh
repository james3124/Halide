#!/bin/sh
# sbom.sh — phone-safe stub (text only, no build).
# Writes minimal SPDX skeleton to sbom/SBOM.spdx.json.
set -eu
mkdir -p sbom
VERSION="0.0-phone"
if [ -f manifests/MANIFEST.lock ]; then
  V="$(grep '^version:' manifests/MANIFEST.lock | awk '{print $2}' || true)"
  if [ -n "${V:-}" ]; then
    VERSION="$V"
  fi
fi
cat > sbom/SBOM.spdx.json <<EOF
{
  "spdxVersion": "SPDX-2.3",
  "name": "HALIDE",
  "documentNamespace": "https://halide.local/sbom/$VERSION",
  "creationInfo": {"created": "builder-fills", "creators": ["Tool: halide-sbom-stub"]},
  "packages": [{"name": "HALIDE", "versionInfo": "$VERSION", "supplier": "TODO-builder-fills", "downloadLocation": "NONE"}]
}
EOF
echo "sbom: wrote sbom/SBOM.spdx.json (HALIDE $VERSION)"
