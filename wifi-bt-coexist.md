# Wi-Fi / Bluetooth Coexistence — Antenna Sharing, Roam Behavior & Test Matrix
**Parent: ch.04 §12, ch.07 §12 · Owner: BSP/Telephony · Per-SKU data in `rf/<sku>/coexist.md`**

## 1. Sharing architecture (what shares what — from datasheet + lab proof)

Most candidate SKUs share 2.4GHz antenna between WLAN + BT (WCN3990-class: PTA — packet traffic arbitration — with firmware-configurable priority). Document per SKU: shared vs dedicated paths (with board-photo antenna marks + schematic page where available), PTA mode + firmware version (PTA behavior changes across fw — version pinned in BLOBS), LTE-B7/B40 harmonic proximity to 2.4GHz (shared-antenna SKUs need the §3 desense check, not assumptions). 5GHz-only WLAN + BT-SCO concurrency is the easy case (record it as the baseline before testing the hard 2.4GHz case).

## 2. Priority policy (who yields — committed, not emergent)

SCO voice (HFP call) > WLAN latency-sensitive (VoWiFi-adjacent, portal-keepalive) > A2DP streaming > WLAN bulk (iperf, downloads). PTA firmware params encoding this order committed per SKU (`rf/<sku>/pta.conf` + fw version — fw bump re-validates §3 fully, no "same params" assumption). Host-side backstop (when fw arbitration misbehaves): NM scan-throttle during active SCO (scan deferral ≤30s with `SCAN_DEFERRED` journal + UI "Wi-Fi paused during call" avoidance — scans deferred, connection kept, user sees nothing), BT retransmit-cap during VoWiFi call (documented tradeoff: A2DP glitch vs call drop — call wins, glitch logged).

## 3. Test matrix (all rows per release per SKU — fw or driver change re-runs all)

| # | Condition | Metric | Bar |
|---|---|---|---|
| 1 | 2.4GHz iperf alone | baseline Mbps | reference |
| 2 | + A2DP streaming | iperf delta | ≤30% drop (ch.04 §12 rule) |
| 3 | + HFP call 10 min | call MOS-subj + iperf | no drop, call ≥4 |
| 4 | 5GHz iperf + A2DP | delta | ≤10% |
| 5 | WLAN roam (AP switch) during A2DP | gap ms | <500ms audio gap |
| 6 | BT reconnect ×5 during iperf | iperf continuity | 0 stalls >2s |
| 7 | LTE B7 upload + 2.4GHz iperf | delta vs LTE-idle | recorded (desense flag if >25%) |
| 8 | Overnight idle (both on, connected) | suspend residency | §10 power gate unaffected |

## 4. Roam behavior (host NM owns roaming — Android follows, ch.05 netd rule)

Roam thresholds (RSSI + blacklist timers) in NM connection profile per SSID-class (home/office/public templates in `rf/roam-profiles/`); Android `WifiService` sees post-roam state via bridge (no independent roam decisions — two roamers ping-pong APs, documented once). Fast-transition (802.11r) tested where infra supports (lab AP configured r/non-r both — result per mode recorded, not assumed).

## Verification

- [ ] All 8 rows green per SKU per release; PTA conf + fw version committed; roam profiles versioned.
