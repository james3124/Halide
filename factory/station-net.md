# station-net.md — flash station network isolation (ch.09 §28)
**Owner: Release + Factory liaison · Phase: factory — compromised office LAN must not reach the flash station**

## Topology (FLASH-VLAN)

```
[office LAN] ──(deny)──> [lab router: DHCP/DNS only]
                              │  dedicated FLASH-VLAN (untagged access ports, no trunk)
                    ┌─────────┴─────────┐
                    │  flash station(s)  │  wifi: BIOS-disabled + rfkill-blocked
                    └─────────┬─────────┘
                        firewall: default-deny inter-VLAN
                        host nftables: factory/station-nftables.conf
```

## Egress allowlist (exactly 3 paths; everything else denied at router + host)

| # | Destination | Purpose | Guard |
|---|---|---|---|
| 1 | canonical git/artifact host | fetch `flashmap.json` + release images | SHA-verified post-fetch against `SHA256.signed.txt` (fetch-then-verify) |
| 2 | transparency repo | read-only, commit-SHA pinned per flashing session, logged per unit | — |
| 3 | NTP single pool host | clock sanity (skew voids signature timestamps) | logged |

## Remote access

- SSH: ed25519, bastion-only, no password, idle-timeout 5 min; session log ships at shift end with flash logs.
- Quarterly game-day: plug office-LAN cable into a staging station + insert mystery stick → selftest must refuse flashing before any unit is touched; refusal-failure = P0 infra bug.

Expected: `station-selftest.sh` → egress probe `allowed-3 reachable, office-LAN+internet unreachable (named failure)`; `iw dev` shows no associated interface.

Fail action: not on FLASH-VLAN → label `UNISOLATED-LAB-ONLY`, tooling refuses release-image flashing (testkey/eng only + per-unit `RMA-UNISOLATED` log tag).
