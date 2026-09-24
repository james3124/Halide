#!/bin/bash
# tests/recovery-auth.sh - recovery log-export auth-gating contract (runbook-recovery S3).
# Rule: encrypted userdata requires lockscreen PIN (rate-limited) before mount;
# unauthenticated export allowed ONLY for unencrypted-boot-failure (pstore+versions).
# Phone-safe: text checks on builder; live asserts on lab unit only. Exit 0/1/2.
# DOD: DoD-recovery,DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
FAIL=0
[ -f recovery/UI.md ] || { echo "FAIL: recovery/UI.md missing (menu contract)"; exit 1; }
grep -qi "PIN.*required\|auth.*required" recovery/UI.md || { echo "FAIL: UI.md lacks auth-gated export rule"; FAIL=1; }
grep -qi "pstore + versions\|pstore.*versions" recovery/UI.md || { echo "FAIL: UI.md lacks unauthenticated pstore-only rule"; FAIL=1; }
grep -q "exit 2" recovery/factory-reset.sh || { echo "FAIL: factory-reset.sh must stay a phone-safe stub (exit 2)"; FAIL=1; }
echo "recovery-auth: static contract OK (auth-gated export + pstore-only exception documented)" | emit
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1 && [ "${HALIDE_LAB:-0}" = "1" ]; then
  R=$(adb shell halide-recovery-drive --auth-probe 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
  case "$R" in
    *tool-missing*) echo "SKIP-live: halide-recovery-drive absent (device/builder only)" ;;
    AUTH-GATED*) echo "live: $R" | emit ;;
    *) echo "FAIL: live recovery export not auth-gated ($R)"; FAIL=1 ;;
  esac
else
  echo "SKIP-live: lab unit checks need adb + HALIDE_LAB=1 (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "recovery-auth: PASS" || echo "recovery-auth: FAIL"
exit "$FAIL"
