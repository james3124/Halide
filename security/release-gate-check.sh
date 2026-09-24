#!/bin/bash
# security/release-gate-check.sh -- release-gate runner (ch.08 S7 checklist)
# Runs every text-level security gate in this dir; device rows (adb) degrade to
# SKIP (exit 2 only if NOTHING could run). Exit contract: 0 PASS / 1 FAIL / 2 SKIP.
# ASCII only, no network, no flash.
set -eu
cd "$(dirname "$0")/.."
FAIL=0; RAN=0
run() {
  DESC="$1"; shift
  RAN=$((RAN + 1))
  if "$@" >/tmp/halide-gate-out.txt 2>&1; then
    echo "GATE-PASS: $DESC"
  else
    CODE=$?
    if [ "$CODE" = 2 ]; then
      echo "GATE-SKIP: $DESC (infra/device only)"
    else
      echo "GATE-FAIL: $DESC"
      head -5 /tmp/halide-gate-out.txt
      FAIL=1
    fi
  fi
}
run "avb text pins"            bash security/avb-verify.sh
run "vb state copy"            bash security/vb-state-check.sh
run "kdf registry"             bash security/kdf-registry-check.sh
run "sepolicy comment lint"    bash security/sepolicy-comment-lint.sh --require-bug --require-expiry --require-test
run "private-key scan"         bash security/leak-scan.sh
run "dmesg leak drill (text)"  bash security/leak-check.sh
run "lockscreen policy (text)" bash tests/lockscreen-policy.sh
if [ "$RAN" = 0 ]; then echo "release-gate-check: SKIP (no gates ran)"; exit 2; fi
[ "$FAIL" = 0 ] && echo "release-gate-check: PASS" || echo "release-gate-check: FAIL"
exit "$FAIL"
