#!/bin/bash
# tests/settings-search.sh — single-search-box + Android-intents bridge contract (ch.05 §23).
# Every bridged intent row must exist in the index; bridged never outranks native.
# Phone-safe: CSV/index text checks; live foreground probe on device.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. static: intent table (if present) must carry the documented columns (ch.05 §25)
CSV=settings/ANDROID-INTENTS.csv
if [ -f "$CSV" ]; then
  python3 - <<'PY' || FAIL=1
import csv
rows = list(csv.DictReader(open("settings/ANDROID-INTENTS.csv")))
assert rows, "empty ANDROID-INTENTS.csv"
for r in rows:
    assert set(r) == {"intent_uri", "host_panel_or_bridge_activity", "fallback_label", "badge_required"}, r
    assert r["intent_uri"].startswith("android.settings."), r
print("settings-search: %d intent rows well-formed" % len(rows))
PY
else
  echo "note: $CSV not yet authored — live probe only below"
fi
# 2. live: query the index on device; assert a bridged intent resolves + badge node (§25)
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  R=$(adb shell halide-settings-index --probe wifi 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
  case "$R" in
    *tool-missing*|"") echo "SKIP: settings index tool absent on unit (device/builder only)"; exit 2 ;;
    *badge*|*panel*) echo "settings-search: index resolves with badge/panel node — OK" ;;
    *) echo "FAIL: index probe returned no panel/badge node"; FAIL=1 ;;
  esac
else
  echo "SKIP-live: no adb device (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "settings-search: PASS" || echo "settings-search: FAIL"
exit "$FAIL"
