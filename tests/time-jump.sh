#!/bin/bash
# tests/time-jump.sh — suspend across DST/time-jump, alarms survive (ch.05 §27 DST rule).
# Host clock wins; container auto-time is slaved (ch.05 §9 conflict rule).
# Text level: timesync config in hybrid/debian. Device level: timedatectl + NITZ journal.
# Phone-safe: text checks only; no clock writes from tests.
# DOD: DoD-standby
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. text: find timesync config in the debian tree
CONF=$(find debian -name '*chrony*' -o -name '*timesyncd*' 2>/dev/null | head -1 || true)
if [ -z "$CONF" ]; then
  echo "SKIP: no chrony/timesync config in hybrid/debian yet (device/builder only)"; exit 2
fi
grep -qiE 'makestep' "$CONF" || { echo "FAIL: $CONF lacks makestep (boot jump would smear)"; FAIL=1; }
grep -qiE 'makestep [0-9.]+ [0-9]' "$CONF" \
  && echo "time-jump: makestep window present in $CONF — OK" \
  || echo "note: makestep form unusual in $CONF — review"
# 2. text: tzdata pin note (ch.05 §27: tzdata bump is a release-notes line)
grep -qi 'tzdata' manifests/MANIFEST.lock 2>/dev/null \
  || echo "note: tzdata version not pinned in MANIFEST.lock (ch.05 §27 rule)"
# 3. live: DST boundary suspend drill needs the vote path (ch.05 §29) — device only
if command -v timedatectl >/dev/null 2>&1 && [ -d /run/halide ]; then
  NTP=$(timedatectl show -p NTP --value 2>/dev/null || echo "?")
  echo "time-jump: host NTP=$NTP (container slaved per ch.05 §27)"
  [ "$NTP" = "yes" ] || { echo "FAIL: host NTP off — auto-time master missing"; FAIL=1; }
else
  echo "SKIP-live: no timedatectl + /run/halide (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "time-jump: PASS" || echo "time-jump: FAIL"
exit "$FAIL"
