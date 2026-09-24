#!/bin/bash
# scripts/cache-audit.sh -- build-cache audit (ch.09 S24, ci/cache-inventory.md).
# No undocumented caches: every cache entry needs key + store + threat model.
# Usage: cache-audit.sh check  (validates ci/cache-inventory.md register)
#        cache-audit.sh emit <manifest-sha8> <builder-digest12> <clang-ver> <branch-suffix>
# Phone-safe: text only. Exit 0 pass / 1 fail / 2 usage.
set -eu
cd "$(dirname "$0")/.."

MODE="${1:-check}"
if [ "$MODE" = "check" ]; then
  INV=ci/cache-inventory.md
  [ -f "$INV" ] || { echo "REFUSED: $INV not found"; exit 2; }
  rc=0
  for c in "ccache" "frozen-fetch" "snapshot" "layer"; do
    grep -qi "$c" "$INV" || { echo "FAIL: cache '$c' missing from register (undocumented caches fail audit)"; rc=1; }
  done
  grep -q "MANIFEST.lock SHA" "$INV" || { echo "FAIL: keys must include MANIFEST.lock SHA"; rc=1; }
  [ "$rc" -eq 0 ] && echo "CACHE-AUDIT OK: 4 registered caches, manifest-keyed"
  exit "$rc"
fi

if [ "$MODE" = "emit" ]; then
  MSHA="${2:?usage: cache-audit.sh emit <msha8> <digest12> <clang-ver> <branch-suffix>}"
  DIG="${3:?usage: cache-audit.sh emit <msha8> <digest12> <clang-ver> <branch-suffix>}"
  CLANG="${4:?usage: cache-audit.sh emit <msha8> <digest12> <clang-ver> <branch-suffix>}"
  SUF="${5:?usage: cache-audit.sh emit <msha8> <digest12> <clang-ver> <branch-suffix>}"
  echo "ccache: ${MSHA}-${DIG}-${CLANG}${SUF}"
  echo "fetch: ${MSHA}-<fetch-stage-hash>"
  echo "debsnap: <snapshot-stamp>-<arch>"
  echo "layers: <dockerfile-digest>"
  echo "note: different manifest = cold cache by construction; hotfix uses release-branch cache only"
  exit 0
fi

echo "usage: cache-audit.sh [check|emit ...]"; exit 2
