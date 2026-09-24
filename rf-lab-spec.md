# RF Lab Spec — Shielding, Callbox, and Interference Control
**Parent: 07-telephony-modem-data.md / wifi-bt-coexist.md (host-owns-modem)**

## 1. Scope and lab authority
This spec governs conducted and radiated modem/Wi-Fi/BT/GNSS verification for HALIDE. Host owns the modem: all RF verdicts are made on host-driven modem paths (ModemManager/oFono + per-carrier profiles from `carrier-profile-example.md`); Android container never drives RF directly and any container-initiated RF observation is informational only. Lab covers bring-up, per-carrier blessing, regression after modem FW or antenna/HW rev, and coexistence spot-checks. Threat-model honesty applies: unverified bands/profiles are listed as untested in release notes, never implied. Redacted logs throughout: RF captures reference SKU + profile + FW hash, never IMSI/IMEI; `support-log-script` redaction runs before any log leaves the bench.

## 2. Shield-bag and shield-box verification
Bags are handling aids, not test chambers — boxes are the verdict environment. Procedure: (1) verify every shield bag on receipt and monthly with phone-inside call-drop test (sealed bag + callbox at −80 dBm must drop within 30 s or bag is failed); (2) label bags `PASS <date>` / `FAIL` (failed bags destroyed, never downgraded to storage); (3) allattach/sensitivity verdicts run in shield box (≥80 dB isolation to 6 GHz, door-switch interlock logged), never in a bag. Box verification weekly: close empty box with coupled antenna, sweep callbox RSSI −50→−110 dBm, confirm DUT follows within ±3 dB and drops cleanly below sensitivity; log curve to `rf/<sku>/box-check/`. DUT placement is fixtured (cradle marks + photo per SKU); hand-holding during radiated takes is forbidden. Any take with door-open event is auto-`FAIL` and re-run.

## 3. Callbox profiles
One pinned callbox (e.g. CMW500/UXM or equivalent, asset tag + cal sticker) drives attach/voice/SMS/data/IMS-smoke. Profiles live in `rf/profiles/<carrier>_<tech>.cfg` mirroring host per-carrier profiles (APN, IMS, VoLTE/VoWiFi flags, band allowlist) — callbox and host profile versions must match or the run is void.

| Profile | Tech / bands | What it proves | Pass gate |
|---|---|---|---|
| `generic_lte_B2-4-12` | LTE attach + default bearer | Baseline attach/data sanity | Attach ≤60 s, ping + HTTP fetch OK |
| `carrierA_volte` | LTE + IMS (VoLTE) | Voice over IMS path | MT/MO call + SMS + IMS registered ≥5 min |
| `carrierB_roam` | Restricted bands + roaming flag | Roam/wildcard behavior | Correct profile select, no silent fallback |
| `wifi-bt-coex` | LTE B7/B41 + Wi-Fi 2.4/5 + BT SCO | Coexistence under load | No voice drop during iperf + SCO (see §6) |
| `gnss-sanity` | GNSS sim (GPS L1) | Antenna path alive | TTFF + C/N0 floor per gnss-deepdive |

Procedure per run: load profile → verify host profile hash matches → conducted attach first (§4) → promote to radiated only on pass → save callbox log + host `mmcli` snapshot with FW version in filename. Carrier approval check: carrier-specific profiles run only on carrier-blessed FW (see modem-fw-qualification); mismatched FW + profile voids the run.

## 4. Conducted vs radiated test split
Conducted (cabled to modem test port via calibrated attenuator) is the verdict path for modem FW and baseband regressions; radiated (OTA in shield box via coupled antenna) is the verdict path for antenna/HW/coexistence changes. Split table:

| Change type | Conducted required | Radiated required | Rationale |
|---|---|---|---|
| Modem FW update | Full battery (§3 all profiles) | Spot (generic + VoLTE) | Isolate baseband from antenna |
| Antenna / flex / enclosure rev | Spot (generic attach) | Full battery + coupling sweep (§5) | Antenna dominates OTA |
| Carrier profile edit | Conducted on affected profile(s) | Radiated only if band allowlist changed | Profile is host config, not RF path |
| Wi-Fi/BT driver or coexistence table | Conducted generic | Full coex profile radiated | Interference is OTA-only |
| Kernel/GKI bump (no modem/antenna touch) | Generic attach only | None unless failure | Smoke, not re-bless |

Conducted chain loss is measured per band at session start (coupler + cable + attenuator) and recorded in dB; unrecorded loss voids sensitivity numbers. Radiated takes record box ID, cradle photo ref, door-log hash, and antenna-coupling notes (§5).

## 5. Antenna-coupling notes
Coupling method is part of the verdict — different couplers give different numbers. Per SKU maintain `rf/<sku>/coupling.md`: coupler model + placement photo with mm ruler, polarization, distance to DUT antennas (main/diversity/GNSS/Wi-Fi), and which enclosure variant (photo of date code — silent HW revs change RF as they change acoustics). Rules: (a) never press coupler against antenna (near-field detune lies); use fixtured 10–20 mm gap; (b) route modem test cables away from GNSS/Wi-Fi antennas and log routing photo on change; (c) diversity/MIMO takes require both chains coupled or explicitly declared SISO with justification; (d) hand/body phantom only for declared SAR-adjacent checks, never for sensitivity claims. Any coupling change triggers box re-verification (§2) before further verdict takes.

## 6. Interference-source inventory
Coexistence claims require a known interferer set, inventoried in `rf/lab/interferers.md` with asset tags and on/off procedure per take.

| Source | Harmonics / overlap | Control procedure |
|---|---|---|
| Lab Wi-Fi AP (2.4 ch1/6/11, 5 ch36/149) | LTE B7/B41 harmonics, BT AFH | AP on pinned channel + iperf load during coex profile; off for sensitivity takes |
| BT SCO headset (pinned model) | 2.4 GHz AFH vs Wi-Fi | Streaming SCO during car/coex call; battery ≥80% |
| Second DUT / hotspot | Desense neighbor | ≥3 m or powered off unless under test; log state |
| USB3 dock / HDMI | Broadband 2.4 GHz noise | Unplug from bench for radiated takes; note if required for test |
| LTE callbox harmonics | GPS L1 / Wi-Fi 2.4 images | GNSS sanity runs with callbox at low power or off; record level |
| Microwave / lab HVAC / LED drivers | Transient broadband | Abort take on observed spike; note in log |

Golden rule: sensitivity takes run with all non-essential emitters off; coexistence takes run with the declared set on — mixed conditions are marked `INVALID`, never averaged.

## 7. Calibration schedule for RF gear
`rf/lab/cal/` holds certs; `rf-lab-check` blocks verdict stamps on expiry, same discipline as acoustic lab.

| Asset | Interval | Record |
|---|---|---|
| Callbox (CMW/UXM) | Annual + after repair/move | Cert PDF + self-test log |
| Shield box isolation | Annual + after seal/door work | Sweep plot to 6 GHz |
| Attenuators / couplers / cables | Annual (cables 6-mo if flexed daily) | Loss table per band, dated |
| SLM-adjacent power sensors / spectrum | Annual | Cert + noise-floor check |
| Reference SIMs / test USIMs | Profile-pinned, replace on carrier notice | Profile hash + carrier approval ref |

Pre-session checklist (logged): box verification current, conducted loss measured, callbox self-test pass, host↔callbox profile hashes match, FW version recorded, interferer states set per §6. Missing item aborts the session — backfilled checklists are treated as failed runs under threat-model honesty.

## Verification
- [ ] Shield bags verified monthly; verdicts only in shield box with door-log; DUT fixtured, never hand-held.
- [ ] Callbox profile hash matches host per-carrier profile; carrier-blessed FW confirmed or run void.
- [ ] Conducted/radiated split follows §4 table; chain loss recorded; coupling notes + photos current.
- [ ] Interferer states declared per take; sensitivity-vs-coex conditions never mixed.
- [ ] All cal current (`rf-lab-check` green); pre-session checklist logged; logs redacted, FW in filenames.
