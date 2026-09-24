# station-image.md — factory flash station definition (ch.09 §28)
**Owner: Release + Factory liaison · Phase: factory/rma — a station that can't meet this spec is UNISOLATED-LAB-ONLY**

## Pinned image

- Base: Debian 12+ builder base image, **digest-pinned** in `factory/station-image.md` + CI (same discipline as ch.09 §23 runners; drift = re-image).
- Packages: frozen lockfile only (flash tooling, avbtool, usbguard, nftables, station-selftest.sh). No browsers, no mail, no package cache daemon.
- Station image SHA256 recorded per flashing session in the per-unit isolation header (ch.09 §28) — an unsigned packet (missing station SHA) is treated as unsigned.

## Re-image recipe (≤30 min or decommission — same bar as runners)

1. Verify base digest against CI pin.
2. Apply frozen package lockfile + `factory/station-nftables.conf` + `factory/usbguard-rules.conf`.
3. Run `station-selftest.sh`: VLAN egress probe (allowed-3 reachable, office-LAN + internet unreachable), `nft list ruleset` diff clean, USBGuard policy SHA match, no `PRIVATE KEY` material, disk ≥20G free, clock/NTP sane (skew fails the shift).
4. Label station `FLASH-VLAN` + date; log station-image SHA in `factory/logs/shift-<date>-<shift>.json`.

## Hard rules

- Full-disk encryption (TPM-sealed where present).
- No private-key material ever (grep is a shift-start check; hit = quarantine station image + rotate deploy keys, ch.09 §13).
- SIGN-X ceremony sticks never touch stations — insertion pages line lead, stick retired.
- Wi-Fi disabled in BIOS + rfkill-blocked; selftest asserts `iw dev` shows no associated interface.

Expected: selftest prints `STATION OK vlan=FLASH-VLAN egress=3/3 usbguard=SHA-MATCH keys=NONE disk=OK clock=OK`.

Fail action: any line non-green = station refuses to flash (enforced in software, not signage).
