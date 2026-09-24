# Modem Firmware Qualification — Intake to Rollback
**Parent: 07-telephony-modem-data.md / carrier-profile-example.md (host-owns-modem, per-carrier profiles)**

## 1. Firmware intake (SHA + carrier approval check)
No modem FW enters HALIDE CI without provenance. Intake procedure: (1) vendor drops FW blob + release notes to `modem/fw/<vendor>_<ver>/` with SHA256 file signed by modem owner; (2) intake script verifies SHA against vendor manifest, records blob hash + manifest hash + receiver + date in `modem/fw/INTAKE.log`; (3) carrier-approval check: each target carrier row in `modem/fw/approval-matrix.md` must show `approved / pending / N/A` with carrier notice ID and expiry — `pending` FW may run in RF lab only, never in field, factory, or OTA; (4) pin host per-carrier profile hashes that this FW was blessed against (profiles are host config; FW + profile pair is the qualified unit, never FW alone). Mismatch rule: FW with changed AT/QMI behavior vs current host profile parser fails intake until profile patch lands and both re-qualify together. Threat-model honesty: unapproved FW is labeled `UNBLESSED-<carrier>` in every log, plot, and footnote — never silently tested as blessed. Redacted logs: intake records contain hashes and versions only, never IMSI/IMEI/dump paths.

## 2. Regression battery (attach / voice / SMS / data / IMS-smoke)
Every candidate FW runs the full battery conducted first (per rf-lab-spec §4), then radiated spot. Battery is scripted as `modem-qual <fw> <profile-set>`; partial batteries do not bless.

| Step | Command / path | Pass gate | Evidence archived |
|---|---|---|---|
| Attach | `mmcli -m 0 --simple-connect` on each blessed profile | Attach ≤60 s, correct APN+bearer | `mmcli` snapshot + callbox log |
| Voice (VoLTE/CSFB per profile) | MT + MO 60 s call via callbox profile | No drop, audio path alive, far-end audible | Callbox trace + acoustic take ref (5-call #1) |
| SMS | MO + MT PDU pair | Both directions ≤30 s | PDU hashes (bodies redacted) |
| Data | Ping + HTTP fetch + 60 s iperf | No stall; throughput within 15% of prior blessed FW | iperf log with FW in filename |
| IMS-smoke | `ims-status` + 5-min registered hold + 1 VoWiFi toggle where profile allows | IMS registered, no flaps, toggle recovers ≤90 s | IMS log excerpt (redacted) + profile hash |
| Power/thermal spot | 10-min call + idle suspend check | No modem crash, host suspend resumes, temp within SKU envelope | `power-results-template` row with FW footnote (§6) |
| Host-bridge check | Locale-agnostic: signal/operator render in host + container | Both stacks agree (dual-stack atomicity) | Screenshot pair |

Any step fail stops blessing for that profile; fixes require new FW or profile rev and full re-run of that profile (no cherry-picked step retries without root-cause note). Flaky pass (1/3) is a fail — record all three attempts.

## 3. Re-blessing triggers per carrier matrix
Blessing is per (FW × profile × SKU × carrier) cell in `modem/fw/bless-matrix.md`. A cell flips to `RE-QUALIFY` on any trigger below; shipping OTA/factory on a `RE-QUALIFY` cell is blocked by CI.

| Trigger | Scope of re-bless | Procedure |
|---|---|---|
| New modem FW (any byte change) | All carriers on that SKU | Full battery §2 on every blessed profile |
| Per-carrier profile edit (APN/IMS/bands) | That carrier cell(s) only | Battery on edited profile(s) + generic attach |
| Carrier approval expiry/notice | That carrier cell | Intake check §1 + battery on that profile; hold field units until green |
| Antenna/flex/enclosure HW rev | All RF cells on that SKU | RF-lab radiated battery per rf-lab-spec §4 + acoustic 5-call (gains couple) |
| Kernel/GKI/modem-driver change | Generic + VoLTE cells | Attach + voice + IMS-smoke; expand on failure |
| Coexistence table / Wi-Fi/BT driver | Coex + VoLTE cells | Radiated coex profile + voice-under-load |

Matrix cells show `FW hash (short) / profile hash / verdict / date / lab box ID`; empty cell means untested — release notes must list it as such (no fake claims of universal blessing). Carrier-specific quirks (roam flags, IMS timers) live in the profile file, never as oral lore — undocumented quirk voids the cell.

## 4. Rollback on FW regression
Regression definition: any §2 gate that passed on prior blessed FW and fails on candidate under identical profile/box/coupling, confirmed over 3 attempts. Procedure: (1) freeze promotion of candidate FW immediately (CI `modem-promote` red); (2) re-run prior blessed FW once to confirm bench health (rules out lab fault); (3) file `modem/fw/regress/<fw>-<profile>-<date>.md` with before/after logs, hashes, box ID, and 3-attempt table; (4) roll factory/OTA pointer back to prior blessed FW for affected cells and note rollback in release notes with reason (honesty over optics); (5) notify carrier contact where approval-attached FW regresses — do not quietly ship prior FW to that carrier without confirming approval still covers it. Rollback images are full modem partitions with SHA in OTA manifest; partial/delta modem flashes are forbidden (brick risk). Devices already flashed with regressed FW in lab are re-flashed and re-baselined (acoustic call #1) before reuse.

## 5. FW version in performance and release footnotes
Every measurement that touches the modem carries its FW. Procedure: `power-results-template`, `audio/<sku>/measurements.md`, RF sensitivity plots, and OTA changelogs include footnote `Modem <vendor> <ver> (<short-SHA>) + profile <name> <short-hash> + <conducted|r radiated> + box <ID>`. Comparison tables across releases must either hold FW constant or flag the FW delta in bold — silent FW swaps inside perf comparisons are treated as data-integrity failures. Factory traveler (`factory-traveler-template.md`) records flashed modem FW hash per unit; OTA manifest records modem partition hash; `eol-export-runbook` retains bless-matrix + regression reports for the support window. Field bug reports without modem FW + profile hash are returned for info before triage (per support-log-script discipline, redacted).

## 6. Redaction, ownership, and honesty gates
Host owns the modem: qualification verdicts are signed by host modem owner + RF-lab owner (2-person rule, same spirit as audio gains). Container logs are never qualification evidence. All archived logs pass `support-log-script` redaction (IMSI/IMEI/numbers/PDU bodies stripped; hashes kept). Claim discipline: release notes list per-carrier bless state verbatim (`blessed / re-qualify / untested / unblessed-FW`); marketing or changelog language claiming broader carrier support than the matrix is a release blocker. Exceptions (ship on `RE-QUALIFY` for emergency fix) require both owners + carrier-contact ack in writing, time-boxed, with follow-up battery date set — verbal exceptions are void.

## Verification
- [ ] Intake logged with double-SHA + approval-matrix state; `pending` FW lab-only; profile hashes pinned.
- [ ] Full battery (§2 table) green per cell over 3-attempt rule; no partial-battery blessing.
- [ ] Bless-matrix cells current; every trigger in §3 table re-qualified; untested cells listed as untested.
- [ ] Regression filed with before/after evidence; rollback pointer + SHA recorded; carrier notified where attached.
- [ ] Every perf/RF/OTA footnote carries FW + profile hash + box ID; factory/field logs redacted; 2-person sign present.
