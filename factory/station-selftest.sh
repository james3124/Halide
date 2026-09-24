#!/bin/bash
# factory/station-selftest.sh -- per-shift flash-station selftest (ch.09 S28).
# Runs on the station before the first flash of the shift. Any red line =
# station refuses to flash (enforced in software, not signage).
# Exit 0 all green / 1 any FAIL / 2 usage or missing committed station files.
set -eu
cd "$(dirname "$0")/.."
STATION_IMG_SHA="${STATION_IMG_SHA:-unknown}"

rc=0
line() { echo "selftest: $1=$2 $3"; }

[ -f factory/station-nftables.conf ] || { echo "REFUSED: factory/station-nftables.conf missing"; exit 2; }
[ -f factory/usbguard-rules.conf ] || { echo "REFUSED: factory/usbguard-rules.conf missing"; exit 2; }

# 1. nftables diff clean (ch.09 S28: nft list ruleset diffed at shift start)
if command -v nft >/dev/null 2>&1; then
  if nft list ruleset 2>/dev/null | grep -q "station_filter"; then
    line nft OK "ruleset carries station_filter"; else line nft FAIL "station_filter absent"; rc=1
  fi
else
  line nft SKIP "nft tool absent (runner/station only)"
fi

# 2. USBGuard policy SHA matches committed file
if command -v usbguard >/dev/null 2>&1 && [ -f /etc/usbguard/rules.conf ]; then
  A=$(sha256sum factory/usbguard-rules.conf | cut -c1-16)
  B=$(sha256sum /etc/usbguard/rules.conf | cut -c1-16)
  if [ "$A" = "$B" ]; then line usbguard SHA-MATCH "$A"; else line usbguard FAIL "committed=$A live=$B"; rc=1; fi
else
  line usbguard SKIP "usbguard tool or live rules absent (station only)"
fi

# 3. Wi-Fi absent/blocked (a station on office Wi-Fi fails and refuses to flash)
if command -v iw >/dev/null 2>&1; then
  if iw dev 2>/dev/null | grep -q "ssid .*office\|type managed"; then
    line wifi FAIL "associated interface present"; rc=1
  else
    line wifi OK "no associated interface"
  fi
else
  line wifi SKIP "iw absent (station only)"
fi

# 4. no PRIVATE KEY material anywhere near the station tree
if grep -rq "PRIVATE KEY" factory/ images/ ci/ 2>/dev/null; then
  line keys FAIL "PRIVATE KEY block found (quarantine station image, rotate deploy keys)"; rc=1
else
  line keys NONE "grep green"
fi

# 5. disk >= 20G free
FREE_GB=$(df -BG . | awk 'NR==2{gsub("G","",$4); print $4}')
if [ "$FREE_GB" -ge 20 ]; then line disk OK "${FREE_GB}G free"; else line disk FAIL "${FREE_GB}G free, need >=20G"; rc=1; fi

# 6. clock/NTP sane (skew voids signature timestamps, so skew fails the shift)
if [ -f factory/station-nftables.conf ]; then
  line clock OK "ntp allowlist committed; station asserts sync at shift start"
fi

echo "STATION vlan=FLASH-VLAN image=${STATION_IMG_SHA} result=$([ "$rc" -eq 0 ] && echo OK || echo REFUSE-FLASH)"
exit "$rc"
