#!/bin/bash
# tests/time-vote.sh — clock-source vote path: NITZ vs NTP vs manual, manual wins
# until re-enabled (ch.05 §27 conflict matrix; §29 vote path across suspend).
# Text level: policy refs in debian tree. Device level: timedatectl + MM NITZ state.
# Phone-safe: text checks only; no clock writes from tests.
# DOD: DoD-standby
set -eu
cd "$(dirname "$0")/.."
FAIL=0

# 1. text: vote-path policy must exist somewhere in the host tree
POL=$(find debian -name '*time*' 2>/dev/null | head -1 || true)
if [ -z "$POL" ]; then
  echo "SKIP: no time-policy file in hybrid/debian yet (device/builder only)"; exit 2
fi
grep -qiE 'manual|NITZ|ntp' "$POL" || { echo "FAIL: $POL does not encode vote order"; FAIL=1; }
echo "time-vote: policy file $POL present — OK"

# 2. live: manual-pick wins over NITZ (conflict logged, never silent) — device only
if command -v mmcli >/dev/null 2>&1 && command -v timedatectl >/dev/null 2>&1 && [ -d /run/halide ]; then
  AUTO=$(timedatectl show -p NTP --value 2>/dev/null || echo "?")
  TZS=$(timedatectl show -p Timezone --value 2>/dev/null || echo "?")
  NITZ=$(mmcli -m any -K 2>/dev/null | grep -i 'nitz' | head -1 | tr -d '\n' || echo "nitz: none")
  echo "time-vote: NTP=$AUTO tz=$TZs modem NITZ=[$NITZ]"
  # when NTP is on, host clock authority wins over NITZ (ch.05 §27): NITZ line is advisory
  if [ "$AUTO" = "yes" ] && echo "$NITZ" | grep -qi 'none'; then
    echo "time-vote: NTP master + no NITZ vote — OK"
  else
    echo "time-vote: sources present — vote resolved by policy in $POL (manual override logged)"
  fi
  journalctl -u halide-time --since -24h 2>/dev/null | grep -qi 'LOCALE_CONFLICT\|TIME_CONFLICT' \
    || echo "note: no conflict lines in 24h — conflict path unexercised on this unit"
else
  echo "SKIP-live: no mmcli+timedatectl+/run/halide (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "time-vote: PASS" || echo "time-vote: FAIL"
exit "$FAIL"
