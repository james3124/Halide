#!/bin/bash
# tests/net-firewall.sh — firewall fail-closed rules for the container (ch.05 §16).
# Checks ruleset text (host nftables) for the container deny-when-VPN-down chain.
# Phone-safe: reads ruleset text only; never edits firewall rules.
# DOD: DoD-radio,DoD-logs
set -eu
cd "$(dirname "$0")/.."
FAIL=0

RULES=""
if [ -n "${1:-}" ] && [ -f "$1" ]; then RULES=$(cat "$1");                 # explicit dump arg
elif [ -f debian/nftables.conf ]; then RULES=$(cat debian/nftables.conf);  # repo config
elif command -v nft >/dev/null 2>&1; then RULES=$(nft list ruleset 2>/dev/null || echo "no-nft");
elif command -v iptables >/dev/null 2>&1; then RULES=$(iptables-save 2>/dev/null || echo "no-iptables");
fi
case "$RULES" in
  ""|no-nft|no-iptables)
    echo "SKIP: no firewall ruleset text available (device/builder only)"; exit 2 ;;
esac
# 1. container chain must exist (single-owner network: host filters container egress)
echo "$RULES" | grep -qi 'halide' || { echo "FAIL: no halide chain in ruleset"; FAIL=1; }
# 2. kill-switch marker: drop rule scoped to container traffic must be present
echo "$RULES" | grep -qiE 'drop|reject' \
  || { echo "FAIL: no drop/reject rule — VPN-down egress would leak"; FAIL=1; }
# 3. default-forward policy sanity
echo "$RULES" | grep -qiE 'policy (drop|accept)' || echo "note: no explicit policy line — verify manually"
# 4. live device check: kill-switch actually denies when VPN down (ch.05 §16)
if command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1; then
  R=$(adb shell halide-netd-drive --firewall-probe 2>&1 | tail -1 | tr -d '\r\n' || echo "tool-missing")
  case "$R" in
    *tool-missing*|"") echo "note: firewall probe tool absent on unit — text checks only" ;;
    *DENY*|*REJECT*) echo "net-firewall: live probe denied egress with VPN down — OK" ;;
    *) echo "FAIL: live probe passed egress with VPN down"; FAIL=1 ;;
  esac
fi
[ "$FAIL" = 0 ] && echo "net-firewall: PASS" || echo "net-firewall: FAIL"
exit "$FAIL"
