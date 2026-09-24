# interferers.md — RF lab interferer inventory (rf-lab-spec §6 — asset tags + on/off per take)
**Owner: RF lab (QA row) · Phase: 2–3 — coexistence claims require this known interferer set**

## Interferers

| Source | Asset tag | Bands / overlap | On/off procedure per take |
|---|---|---|---|
| Lab Wi-Fi AP | RF-AP-01 | 2.4 ch1/6/11, 5 ch36/149 | pinned channel + iperf load for coex profiles; OFF for sensitivity takes |
| BT SCO headset (pinned model) | RF-BT-01 | 2.4 GHz AFH vs Wi-Fi | streaming SCO during car/coex call; battery ≥80% |
| LTE callbox | RF-CB-01 | B2/B4/B7/B41 (REF-A bands) | cell pinned to band + power per scenario; off = RF-shield only |
| GNSS simulator | RF-GNSS-01 | L1 C/A | static scenario file per take; off for open-sky TTFF |
| Microwave reference | RF-MW-01 | 2.45 GHz broadband | bench-end only, never in box; log presence or absence |

## Shielding notes

- Shield bags are handling aids, not chambers — monthly phone-inside call-drop test, `PASS <date>` labels, failed bags destroyed (rf-lab-spec §2).
- All attach/sensitivity verdicts run in the shield box (≥80 dB isolation to 6 GHz, door interlock logged); box sweep verified weekly.
- DUT fixtured per cradle marks — hand-holding during radiated takes forbidden; door-open event auto-FAILs the take.
- Conducted chain loss measured per band at session start; unrecorded loss voids sensitivity numbers.

Expected: every take checklist line cites interferer states per this table; missing state = session abort (rf-lab-spec §7).

Fail action: unlogged interferer state = take invalid, re-run.
