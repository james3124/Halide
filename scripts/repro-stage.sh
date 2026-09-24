#!/bin/bash
# repro-stage.sh <stage> <log-id> — emit a staged-repro checklist from MANIFEST.lock (ch.09 S18).
# Phone-safe: prints text; runs no builds. The recorded command beats tribal knowledge.
set -eu
cd "$(dirname "$0")/.."
STAGE=${1:?usage: repro-stage.sh <stage> <log-id>}; LOGID=${2:?usage: repro-stage.sh <stage> <log-id>}
LOCK=manifests/MANIFEST.lock
[ -f "$LOCK" ] || { echo "REFUSED: $LOCK not found"; exit 2; }

MSHA=$(sha256sum "$LOCK" | cut -c1-8)
DIGEST=$(grep -o 'builder-digest: .*' "$LOCK" | awk '{print $2}')

cat <<EOF
# Staged-repro checklist — stage=$STAGE log=$LOGID manifest-sha8=$MSHA
# Rule (ch.09 S18): identical digest + identical MANIFEST.lock, or the repro is not a repro.
- [ ] CI log header read: AOSP rev / kernel fragment / overlay file list noted (bisect starts here)
- [ ] builder image digest matches MANIFEST.lock: ${DIGEST:-TODO-sha256-of-ci-Dockerfile}
- [ ] cache purged or keyed to manifest: cache key = ${MSHA}-<digest12>-<clang-ver> (ch.09 S7)
- [ ] stage re-run container-locally: build-all.sh $STAGE (same flags as CI)
- [ ] result classified: PASS-locally+FAIL-CI = runner/cache divergence -> purge + re-run
-                           FAIL-locally = real breakage -> bisect MANIFEST delta
- [ ] outcome + command recorded in logs/repro-$STAGE-$(date -u +%F).md (append, never overwrite)
EOF
exit 0
