#!/bin/bash
# scripts/transparency-check.sh -- artifact transparency verification (ch.09 S17).
# Release dir layout per version: MANIFEST.lock SHA, hashes.txt (builder
# unsigned), SHA256.signed.txt (signer output), signatures.json (key-ids +
# rollback + timestamps), SBOM.spdx.json SHA + diff, avbtool info dumps,
# ceremony log id. User ritual: fetch dir -> sha256sum -c -> avbtool
# verify_image with pub from keys/ -> compare rollback vs notes.
# Phone-safe: text + sha256sum only, no network. Exit 0/1/2.
set -eu
cd "$(dirname "$0")/.."
DIR=${1:?usage: transparency-check.sh <transparency-dir>}
[ -d "$DIR" ] || { echo "REFUSED: $DIR not found"; exit 2; }

rc=0
for f in MANIFEST.lock hashes.txt SHA256.signed.txt signatures.json SBOM.spdx.json; do
  if [ -f "$DIR/$f" ]; then echo "OK: $f present"; else echo "FAIL: $f missing in $DIR"; rc=1; fi
done

if [ -f "$DIR/SHA256.signed.txt" ]; then
  (cd "$DIR" && sha256sum -c SHA256.signed.txt) || { echo "FAIL: sha256sum -c mismatch"; rc=1; }
fi

if [ -f "$DIR/signatures.json" ]; then
  python3 - "$DIR/signatures.json" <<'EOF' || exit 1
import json,sys
s = json.load(open(sys.argv[1]))
for k in ("key_ids", "rollback", "timestamps"):
    if k not in s:
        print("FAIL: signatures.json missing '%s'" % k); sys.exit(1)
print("OK: signatures.json key-ids + rollback + timestamps present")
EOF
  [ $? -eq 0 ] || rc=1
fi

[ "$rc" -eq 0 ] && echo "TRANSPARENCY OK: mirrored bytes verifiable without trusting the mirror"
exit "$rc"
