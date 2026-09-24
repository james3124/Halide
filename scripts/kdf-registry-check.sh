#!/bin/bash
# kdf-registry-check.sh — KDF registry schema + weak-primitive ban (ch.08 §32 normative JSON).
# Weak names (md5/sha1/des/…) are checked ONLY in approved entries; the registry's own
# `prohibited` block documents the ban and must not trip it. Phone-safe text checks only.
set -eu
cd "$(dirname "$0")/.."
F=security/kdf-registry.json
[ -f "$F" ] || { echo "REFUSED: $F not found (Security owns this file; this script creates nothing)"; exit 2; }

python3 -m json.tool "$F" >/dev/null 2>&1 || { echo "FAIL: $F does not parse as JSON"; exit 1; }
echo "OK: $F parses"

rc=0
# approved entries must never name a weak primitive (prohibited block is the ban doc, not a use)
python3 - "$F" <<'EOF' || rc=1
import json, re, sys
d = json.load(open(sys.argv[1]))
weak = re.compile(r"md5|sha-?1|\bdes\b|3des|rc4|md4", re.I)

def strings(x):
    if isinstance(x, str): yield x
    elif isinstance(x, dict):
        for k, v in x.items():
            yield k
            yield from strings(v)
    elif isinstance(x, list):
        for v in x: yield from strings(v)

approved = d.get("approved", [])
hits = [s for a in approved for s in strings(a) if weak.search(s)]
if hits:
    print("FAIL: weak KDF name in approved entries: %s" % sorted(set(hits)))
    raise SystemExit(1)
print("OK: approved entries use no weak KDF (Argon2id + AES-XTS per ch.08 §32)")
prohibited = json.dumps(d.get("prohibited", {}))
for w in ("md5", "sha1", "des"):
    if w not in prohibited:
        print("FAIL: prohibited block does not ban %s" % w)
        raise SystemExit(1)
print("OK: prohibited block bans md5/sha1/des")
EOF

[ "$rc" -eq 0 ] && echo "KDF-REGISTRY OK"
exit $rc
