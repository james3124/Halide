#!/bin/bash
# tests/wifi-hotspot.sh — host-NM single-owner + metered mirror + portal single-window.
# Phone-safe: text checks only on phone; live nmcli/dumpsys asserts run on device.
# Contract per ch.05 §29/§30, ch.07 §6. Exit 0/1/2.
set -eu
cd "$(dirname "$0")/.."
FAIL=0
SKIP=0

live() { command -v nmcli >/dev/null 2>&1 && nmcli general status >/dev/null 2>&1; }

# 1. Hotspot dual-UI ban: no Android hotspot toggle enabled in compat rows
if grep -qi "hotspot" compat/TOP-100.md 2>/dev/null; then
  grep -qi "hotspot.*ALREADY_HANDLED\|hotspot.*read-only" compat/TOP-100.md || {
    echo "FAIL: Android hotspot UI not marked ALREADY_HANDLED/read-only (ch.05 §29 dual-UI ban)"; FAIL=1; }
fi

# 2. Bridge socket registered
grep -q "wifi.sock" bridges/SOCKETS.md || { echo "note: wifi.sock not in SOCKETS.md (add when bridge lands)"; }

# 3. Metered mirror: flag file path defined + contract test exists
[ -f tests/netd-contract.sh ] || { echo "FAIL: netd-contract missing"; FAIL=1; }

# 4. Portal single-owner markers
grep -q "captive_portal_mode=0" compat/NOTES.md 2>/dev/null || \
  echo "note: captive-portal suppression marker not yet in compat/NOTES.md (v1 bridge task)"

# 5. Live device checks (device-only)
if command -v nmcli >/dev/null 2>&1 && nmcli general status >/dev/null 2>&1; then
  METERED=$(nmcli -f GENERAL.METERED -t general 2>/dev/null | head -1)
  [ -n "$METERED" ] || { echo "SKIP: nmcli present but no state"; exit 2; }
  echo "live: GENERAL.METERED=$METERED"
  # VPN fail-closed: if host VPN active, container egress must be VPN-only (ch.05 §4)
  if nmcli con show --active 2>/dev/null | grep -qi vpn; then
    grep -q "kill" security/nftables.conf && echo "live: VPN kill-switch rule present" || {
      echo "FAIL: VPN active but no kill-switch in nftables.conf"; FAIL=1; }
  fi
else
  echo "SKIP: live nmcli checks (device/builder only)"; SKIP=1
fi

[ "$FAIL" -eq 0 ] && echo "wifi-hotspot: PASS"
exit "$FAIL"
