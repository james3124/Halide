# rf/refa/coexist.md -- Wi-Fi / BT coexistence data for SKU refa (wifi-bt-coexist, per-SKU)
# Owner: BSP/Telephony. ASCII only. No results claimed -- TODO until bench runs.

## 1. Sharing architecture

- shared_vs_dedicated: TODO (board-photo antenna marks + schematic page where available)
- pta_mode: TODO (WCN3990-class PTA; firmware version pinned in BLOBS -- PTA behavior
  changes across fw, version recorded)
- lte_harmonic_proximity: TODO (B7/B40 vs 2.4GHz desense check, not assumptions)
- baseline: 5GHz-only WLAN + BT-SCO concurrency recorded FIRST (easy case before hard 2.4GHz case)

## 2. Priority policy (committed, not emergent)

SCO voice (HFP call) > WLAN latency-sensitive > A2DP streaming > WLAN bulk.
Params: rf/refa/pta.conf + fw version (fw bump re-validates S3 fully).
Host backstop: NM scan-throttle during active SCO (deferral <=30s, SCAN_DEFERRED journal;
  scans deferred, connection kept, user sees nothing); BT retransmit-cap during VoWiFi call
  (A2DP glitch vs call drop -- call wins, glitch logged).

## 3. Test matrix (all rows per release per SKU; fw or driver change re-runs all)

| # | Condition | Metric | Bar | Result |
|---|---|---|---|---|
| 1 | 2.4GHz iperf alone | baseline Mbps | reference | TODO |
| 2 | + A2DP streaming | iperf delta | <=30% drop | TODO |
| 3 | + HFP call 10 min | call MOS-subj + iperf | no drop, call >=4 | TODO |
| 4 | 5GHz iperf + A2DP | delta | <=10% | TODO |
| 5 | WLAN roam (AP switch) during A2DP | gap ms | <500ms audio gap | TODO |
| 6 | BT reconnect x5 during iperf | iperf continuity | 0 stalls >2s | TODO |
| 7 | LTE B7 upload + 2.4GHz iperf | delta vs LTE-idle | recorded (desense flag if >25%) | TODO |
| 8 | Overnight idle (both on, connected) | suspend residency | S10 power gate unaffected | TODO |
