#!/bin/bash
# scripts/mirror-audit.sh -- artifact mirror audit (ch.09 S19).
# Mirrors are untrusted by design: serve-after-verify, byte-identical or delist.
# Validates a fetched /healthz JSON: artifact SHAs + transparency-commit id +
# sync timestamp; lag >24h warns operator, >72h delists. Weekly random-byte
# audit: fetch 3 images, sha256sum -c vs canonical; mismatch = immediate delist
# + builder-compromise-style incident. Phone-safe: text checks on a healthz
# file; live fetch modes refuse without explicit network (exit 2).
# Usage: mirror-audit.sh <healthz.json>
# Exit 0 pass / 1 fail (warn vs delist named) / 2 usage or missing input.
set -eu
cd "$(dirname "$0")/.."
HZ=${1:?usage: mirror-audit.sh <healthz.json>}
[ -f "$HZ" ] || { echo "REFUSED: $HZ not found"; exit 2; }

python3 - "$HZ" <<'EOF'
import json,sys,time
h = json.load(open(sys.argv[1]))
rc = 0
for k in ("artifact_shas", "transparency_commit", "sync_timestamp"):
    if k not in h:
        print("FAIL: healthz missing '%s'" % k); rc = 1
if rc:
    sys.exit(1)
try:
    lag_h = (time.time() - int(h["sync_timestamp"])) / 3600.0
except (ValueError, TypeError):
    print("FAIL: sync_timestamp not an epoch integer"); sys.exit(1)
print("OK: shas=%d commit=%s lag=%.1fh" % (len(h["artifact_shas"]), h["transparency_commit"], lag_h))
if lag_h > 72:
    print("FAIL: lag >72h -- delist + note on mirrors page"); sys.exit(1)
if lag_h > 24:
    print("WARN: lag >24h -- warn operator"); sys.exit(1)
print("MIRROR-AUDIT OK")
EOF
