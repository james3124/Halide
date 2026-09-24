#!/bin/bash
# scripts/sbom-diff.sh -- SBOM diff vs previous release (ch.09 S11).
# New blobs are news, not footnotes: +new ~upgraded -removed section for the
# release notes, computed from SPDX package name+versionInfo pairs.
# Phone-safe: text only (python3 + JSON). Exit 0 diff emitted / 1 parse fail / 2 usage.
set -eu
cd "$(dirname "$0")/.."
OLD=${1:?usage: sbom-diff.sh <old.spdx.json> <new.spdx.json>}
NEW=${2:?usage: sbom-diff.sh <old.spdx.json> <new.spdx.json>}
[ -f "$OLD" ] || { echo "REFUSED: $OLD not found"; exit 2; }
[ -f "$NEW" ] || { echo "REFUSED: $NEW not found"; exit 2; }

python3 - "$OLD" "$NEW" <<'EOF'
import json,sys
def pkgs(p):
    d = json.load(open(p))
    return {x.get("name", "?"): x.get("versionInfo", "?") for x in d.get("packages", [])}
try:
    old, new = pkgs(sys.argv[1]), pkgs(sys.argv[2])
except (ValueError, KeyError) as e:
    print("FAIL: SPDX parse error: %s" % e); sys.exit(1)
added = sorted(set(new) - set(old))
removed = sorted(set(old) - set(new))
upgraded = sorted(n for n in set(old) & set(new) if old[n] != new[n])
print("SBOM DIFF: +%d ~%d -%d" % (len(added), len(upgraded), len(removed)))
for n in added: print("  + %s %s (new blob -- named in notes)" % (n, new[n]))
for n in upgraded: print("  ~ %s %s -> %s" % (n, old[n], new[n]))
for n in removed: print("  - %s %s" % (n, old[n]))
EOF
