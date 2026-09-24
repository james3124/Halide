# Bridge Protocol: halide-netd-bridge
**Parent: ch.05 §9 · Owner: Platform/Net · Version: v1 · Rule: single-stack, NM authoritative**

## 1. Parties & transport

Host daemon `halide-netd-bridged` (watches NetworkManager via D-Bus `org.freedesktop.NetworkManager`, runs as `halide-net`) ↔ container proxy `libnetd-halide` (intercepts `netd` binder calls before they reach a real netd — there is no independent netd acting on interfaces) over `/run/halide/netd-bridge.sock` (`0660 root:halide-net`, `SO_PEERCRED` allowlist: container `network_stack` only). Framing: length-prefixed protobuf `NetdEnvelope` (`proto_v=1`).

## 2. Call translation table (normative — every intercepted call listed)

| Android netd call | Bridge action | Mismatch behavior |
|---|---|---|
| `interfaceSetCfg(if, up/down)` on NM-managed if (`wlan0`, `rmnet_data0`) | validate vs NM state; matching → ACK | contradictory (bring down NM-up if) → `PERMISSION_DENIED` + journal + `dumpsys connectivity` shows `HALIDE-BRIDGED` |
| `networkAddRoute/removeRoute` | compare to NM route table; matching → ACK | extra route → install as **policy-routed low-priority** (metric +20000, marked `halide-android`) or reject if overlapping default; logged |
| `setDnsServersForNetwork` | forward to `systemd-resolved` per-link DNS if link matches; else NACK | container-local DNS never becomes system truth |
| `firewallSetUidRule` (app block) | translate to host nftables UID-mark rule (ch.08 §10) with counter | verify counter increments in `tests/net-firewall.sh` |
| `tetherStart/Stop` | forward to NM shared-mode (host owns NAT/dnsmasq) | second NAT inside container forbidden — reject + log |
| `vpnEstablish` (container-side VPN app) | register TUN fd + mark; default-route ownership arbitration (§3) | conflicting host VPN → newer wins with user-visible prompt (no silent route steal) |
| `getInterfaceList` | return NM interface list (filtered: hide `lo`, show metered flag) | — |
| `trafficGetStats` (per-UID) | merge host conntrack counters + container-reported app counters | reconciled hourly; drift >10% → `NET_ACCT_SKEW` metric |

Calls not in this table: default-reject with `UNKNOWN_CALL` + metric (new Android versions add netd calls — each must be triaged into this table before the AOSP bump MR lands).

## 3. Default-route & VPN arbitration

Invariant: exactly one default route owner. Priority: active host VPN TUN > host physical (WWAN/WLAN) > container VPN TUN (only when host has no VPN). Ownership change emits `DEFAULT_ROUTE {owner, if, via_tun}` to both sides + user-visible "VPN active" indicator state sync (the indicator must never lie — test asserts indicator vs `ip route get 8.8.8.8` agreement over 50 flaps). Kill-switch (ch.08 §10): with host kill-switch on, container egress without VPN mark drops (fail-closed proven by `tests/vpn-leak.sh`: 10 flaps, 0 leaks or P0).

## 4. Meteredness & captive portals

NM meter flag (`Metered=yes/no/guess`) mirrored to Android `ConnectivityService` (`NET_CAPABILITY_NOT_METERED` toggled) — big-download guards work. Captive portal: host portal detection authoritative (`connectivity-check`); Android portal login activity deep-linked from host notification (single login flow, credentials entered once). Portal-login success re-emits `NET_VALIDATED` to container (apps waiting on validation resume without manual toggle).

## 5. DNS architecture (single resolver)

`systemd-resolved` is the only recursive path. Container DNS queries route to host stub (`/run/halide/dns-stub`) with per-link routing preserved (VPN link DNS for VPN domains — split-DNS table from NM). No second cache with divergent TTL: stub honors upstream TTL exactly; negative caching capped 30s (documented). DNS leak test: with VPN on, `tcpdump` on physical if shows zero port-53 from container (automated, `tests/dns-leak.sh`).

## 6. Limits, security, contract test

Max message 32KB; queue 256; drop-newest data-stats with counter (signaling never dropped — priority shed order: stats → routes-refresh → dns-hints → signaling-last). `execve` denied (seccomp); fuzz `fuzz_netd_parser`. Contract `bridges/tests/netd_contract.sh`: fake NM state machine (up/down/VPN/portal) + fake netd caller asserting translation table rows, route-arbitration flips, meter mirror, DNS-stub routing, leak tests green.

## Verification

- [ ] Translation table fully covered by contract test; unknown-call reject proven.
- [ ] 50-flap route/VPN test with indicator agreement; `vpn-leak.sh` + `dns-leak.sh` green.
