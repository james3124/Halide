# Wi-Fi / Hotspot / Data — Host Single-Owner Contracts
**Parent: ch.05 §29/§30, ch.07 §6 · Owner: Platform/Telephony · v1 scope**

## Single-owner table (the dual-UI ban, restated as wiring)

| Feature | Owner | Android sees | Banned duplicate |
|---|---|---|---|
| Wi-Fi STA (scan/join/PSK) | host NetworkManager | bridged state, SSID list read-only | Android Wi-Fi picker |
| Hotspot/tethering | host NM (AP mode + DHCP + NAT, 1 client v1) | TetheringManager state read-only; toggle intent → `ALREADY_HANDLED` | Android hotspot tile toggle |
| LTE data | host NM via MM bearer (wwan0/rmnet) | metered flag mirrored (§9 big-download guard) | Android APN editor (override: `persist.halide.apn_override`, never clobbered) |
| Captive portal | NM connectivity-check + login window | bridged banner "Wi-Fi needs sign-in" → host Epiphany | `CaptivePortalLogin` (`captive_portal_mode=0`) |
| VPN | host (kill-switch in `security/nftables.conf`) | fail-closed egress (tests/vpn-leak.sh) | per-app VPN inside container |
| Bluetooth | host BlueZ/PipeWire (HFP AG + A2DP) | bridged `BluetoothHeadset` state | raw HCI passthrough (ch.07 §12) |

## PSK/password handling
- Wi-Fi PSKs live in host NM connection profiles (root-protected `/etc/NetworkManager/system-connections/`, `0600`) — never synced into the container (bridge exports state, not secrets).
- Hotspot PSK rotation is a bridge toggle with `SearchKeywords` exposure (ch.05 §23 searchable without a second config UI).
- Meteredness mirror contract: `dumpsys connectivity | grep -i metered` must match `nmcli -f GENERAL.METERED` within one poll (netd-contract fails on mismatch).

## Verification
```bash
tests/wifi-hotspot.sh   # text contract on phone; live asserts device-only
# Expected (phone): wifi-hotspot: PASS (exit 0, live lines absent)
tests/netd-contract.sh
# Expected: PASS rows incl. wifi-up ≤3s route, VPN fail-closed, ndc PERMISSION_DENIED
```
