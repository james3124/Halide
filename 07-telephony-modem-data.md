# 07 — Telephony, Modem, Mobile Data & Messaging
**Budget: 60,000 chars · Phases: 2–3 · Owner: Telephony · Highest user-visible risk**

## 1. Ownership (binding)

Host owns the modem. ModemManager + NetworkManager are authoritative for registration, voice, SMS, data bearers. Android RIL is a client of the bridge, not a second master. Two masters = double attach, SIM lockouts, carrier bans — forbidden by design.

```
Modem fw → QRTR/QMI → ModemManager (host) ─┬─ GNOME Calls (voice)
                                            ├─ Chats (SMS)
                                            ├─ NetworkManager (LTE data)
                                            └─ halide-ril-bridge ─→ rild/IRadio (container)
```

## 2. Bring-up ladder (do not skip steps)

1. Host sees modem: `mmcli -L`, `qmicli --dms-get-ids` (IMEI redacted in logs).
2. SIM ready: `mmcli -i <idx>` shows `sim-properties`, PIN handling via Settings.
3. Register: `mmcli -m <m> --simple-connect="apn=..."` or NM; `mmcli -m <m>` → `state: connected`, RAT + signal bars.
4. Voice: `mmcli -m <m> --voice-create-call` test call to echo number; audio path per ch.04 proxy.
5. SMS: `mmcli -m <m> --messaging-create-sms` loopback; then Chats UI.
6. Bridge: Android `dumpsys telephony.registry` mirrors host (same operator, same signal ±1 bar, same call state ≤2s lag).
7. Android app test: one banking/2FA SMS + one F-Droid VoIP-adjacent app (no IMS claims).
8. IMS/VoLTE: single-carrier attempt; record `ImsService` registration result; fallback plan documented.

Each step has a must-pass gate; IMS failure does not block data/voice-CS milestones.

## 3. APN & carrier matrix

`carrier/<mcc-mnc>/apn.json` per tested carrier (APN, auth, MVNO type, IMS APN separate). Auto-provision from `mobile-broadband-provider-info` + manual override in Settings. Roaming: data-roaming off by default; prompt on new MCC.

## 4. Calls & audio routing

GNOME Calls rings for MT; Android Dialer hidden v1. HFP to car/headset via host BlueZ/PipeWire (Android BT sees bridged HFP, not raw HCI). Emergency calls: route via host dialer always; test per region build with carrier blessing or documented untested flag — never claim untested emergency support.

In-call audio: modem PCM → host mixer gains in `audio/<sku>/call-gains.conf` (earpiece/speaker/mic/EchoRef). Tune with 5 scripted calls (quiet/street/car/speaker/headset); record PESQ-adjacent subjective scores (no fake precision).

## 5. SMS/MMS

Host store of record v1 (`~/.local/share/chats` + ModemManager SMS). Bridge mirrors to Android provider read-only v1 (document direction!). MMS: APN+MMSC per carrier; test 3 inbound/outbound with 500KB image; group MMS best-effort.

## 6. Data & hotspot

NM owns LTE bearer (`wwan0`/rmnet DATA); USB/Wi-Fi hotspot via NM shared mode to 1 client (v1 gate). Android sees metered/unmetered flag mirrored (so Play-store-equivalent big downloads respect meter). VPN interaction per ch.05 §4.

Throughput gates (same cell, same hour, 3 runs): attach ≤90s post-boot; 1h iperf without drop; hotspot 30 min; idle 8h no detach. Record vs stock in `carrier/<id>/perf.md`.

## 7. Logs & redaction

Collect: `journalctl -u ModemManager`, `mmcli --output-json` (redact), `logcat -b radio`, `qrtr-lookup`, `dmesg`. Commit only redacted bundles (`halide-log-collect --redact`). IMSI/IMEI/ICCID never in git.

## 8. Failure table

| Symptom | Check | Fix |
|---------|-------|-----|
| SIM not detected | `mmcli -i`, SIM GPIO/voltage | DT pinctrl or SIM detect polarity; try second SIM SKU |
| Registers, no data | APN, `nmcli c`, `qmicli --wds-get-packet-service-status` | APN auth/MVNO mismatch; capture `QMI_WDS` verbose once |
| Android shows No Service, host OK | ril-bridge status, `service list radio` | bridge desync; restart bridge (not whole container) + file bug with both logs |
| SMS delayed after airplane toggle | MM suspend/resume, modem fast-dormancy | recovery timer ≤60s gate; modem reset via `mmcli -m --reset` last resort + log |
| One-way audio | call-gains, PCM routing, HFP vs handset | isolate: host-only call (no Android) → then bridged; diff mixer dumps |

## 9. ModemManager/QMI bring-up detail (host truth)

MM version pinned in manifest (≥1.20 for QRTR maturity). Modem object model: `mmcli -L` → `/org/freedesktop/ModemManager1/Modem/N` with `primary-port: cdc-wdm0`, `drivers: qmi_wwan,rmnet`. Plugin selection: force `qcom-soc` plugin where autodetect flaps (record `mmcli -m N --command` plugin name in `carrier/` notes — plugin flapping between `generic` and `qcom` across reboots is a real bug class; pin it).

Bearer setup (QMI WDS): APN profile id per carrier (`qmicli --wds-create-profile`), then `--wds-start-network=apn=...,ip-type=4` for manual test before NM owns it. NM owns production path (`gsm` connection with `apn`, `number=*99#` legacy never used on LTE — document). Signal polling: MM `SignalQuality` every 10s idle, 2s in-call (power tradeoff recorded); Android mirror ≤2s lag verified by timestamped log diff (`host-signal.log` vs `dumpsys telephony.registry`).

SIM toolkit (STK): v1 informational — basic SIM PIN/PUK via Settings; carrier STK menus (balance checks) best-effort via `mmcli --stk-*` where MM supports; document per-carrier STK result (pass/fail, never claim untested STK).

Dual-SIM (if hardware): v1 single-active-SIM gate (second slot enabled only after single-SIM DoD passes; DSDS data-switch documented as Phase-4). eSIM/LPA: out of scope v1 (no SM-DP+ claims; record hardware eUICC presence for roadmap).

## 10. IMS/VoLTE attempt protocol (timeboxed, honest)

Timebox: 3 engineer-weeks per carrier, then document-and-move-on (IMS sinkholes kill projects). Ladder: (1) `qmicli --ims-*` / PDC tool check IMS APN attached, (2) `ImsService`/`ImsResolver` logs (`logcat -b radio | grep -i ims`), (3) `dumpsys telephony.registry` shows `mImsRegistered=true`, (4) test MO/MT VoLTE call with `VoLTE` icon + codec (`AMR-WB` in `dumpsys telecom`). If step 1 never attaches, stop — modem firmware/carrier policy blocks third-party OS (common); record QMI error code + firmware version, publish fallback (CSFB/3G where networks still allow; where carriers are VoLTE-only, label the SKU/carrier combo "data-only v1" explicitly — never sell voice on a combo that can't do it).

Emergency calls over IMS (e911/VoLTE-E911): regulatory third rail — test only with carrier blessing on blessed firmware; otherwise route CS and flag. Release notes carry per-carrier emergency status (VERIFIED-ON <carrier,date> / UNTESTED — the latter in bold, no exceptions).

## 11. Carrier matrix files (concrete schema)

`carrier/<mcc-mnc>/profile.json`:

```json
{"carrier": "Example Mobile", "mcc_mnc": "310260", "apn": "fast.example",
 "auth": "none", "mvno_type": "gid", "ims_apn": "ims", "mmsc": "http://mmsc.example",
 "voice": "CSFB-verified-2026-05-01 | VoLTE-attempted-failed-QMI-0x4e | UNTESTED",
 "emergency": "UNTESTED", "data_perf_mbps_med": 42.5, "notes": "SIM PIN required on first insert"}
```

`perf.md` per carrier: attach time (3 runs), iperf medians up/down, hotspot 30-min stability, idle 8h detach count, vs-stock table (same cell/hour — drive-test discipline, not desk guesses). Roaming: new-MCC prompt + data-roaming-off default verified by swapping to a roaming SIM in lab (or documented untested).

## 12. Bluetooth HFP/A2DP + Wi-Fi calling notes

Host BlueZ owns HCI (ch.04 §12 option A). HFP: `ofono`/`hsphfpd` AG role on host; car kit pairs to host; Android sees bridged `BluetoothHeadset` state (call audio routed modem-PCM→SCO→car, never through container DSP). Test matrix: 10-min HFP call (car kit or reference headset model recorded), A2DP 30-min music from each side, AVRCP skip both directions, reconnect-after-toggle ×5. Wi-Fi calling (VoWiFi): depends on IMS (see §10) — if IMS fails, VoWiFi fails; single line in matrix, no separate project.

## 13. Messaging deep-dive (SMS receipt discipline)

Inbound: modem → MM (`--messaging-list-sms`) → Chats DB write (dedupe by PDU hash — multipart reassembly with 60s window; duplicates from modem retransmits are real, dedupe is a gate) → bridge mirror to Android provider (read-only flag). Outbound host: Chats → MM send → delivery-report tracked (PENDING/SENT/DELIVERED states visible; 2FA use-case needs this). Outbound Android app: `SEND_SMS` intent intercepted → MM send → `sentIntent` RESULT_OK/ERROR with real error mapping (no fake success — radio-off returns ERROR, tested). Long/concatenated: 160→153-char segmentation verified with 3× 300-char messages each direction; UDH correctness checked against stock-received reference (one stock phone in lab as oracle, documented).

MMS: `mmsd-tng` (host) with per-carrier MMSC/APN; 500KB image ×3 each direction; group MMS best-effort (document thread-merge behavior). 2FA OTP auto-fill: host Chats exposes OTP to Android via bridge `SMS_RETRIEVER`-compatible broadcast for allowlisted packages (banking acceptance criterion P1 — test with 2 real OTP flows, redacted).

## 14. Signal bars & indicator honesty (bars are a UI contract)

Mapping committed per SKU (`telephony/<sku>/bars.json`): dBm→bars thresholds measured against the modem's reported values (not copied from stock screenshots — different baseband scaling lies differently). Rules: airplane/shutdown states override bars (never stale 4-bars with dead modem — `MODEM_DEAD` clears indicators ≤3s, tested by killing rproc in harness); roaming `R` badge mirrors MM `home-only` flag (ch.07 §3 roaming default-off); data-activity arrows reflect actual bearer traffic (1s window), not animation. Indicator-vs-truth audit: 50-state script (register/deregister/airplane/SIM-pull/data-toggle) asserting every indicator matches `mmcli` within 3s — 0 mismatch to pass.

## 15. Modem crash & recovery ladder (modems crash — plan the crash)

Detection: QRTR hello timeout (5s) → `MODEM_SUSPECT`; `rproc` state `crashed` → `MODEM_DOWN`. Response (automatic, no user tap): (1) freeze new MO dials with "Radio restarting" (queued 30s, ch.05 ril-bridge §4), (2) `rproc` restart via sysfs (or `mmcli --reset` fallback), (3) re-run bring-up ladder §2 steps 1–3 (attach, no full re-provision), (4) replay queued dials/SMS with user confirm for SMS >60s old (stale-text guard — sending a 5-min-old "on my way" without asking is a bug, not a feature). Post-mortem: `ramoops` + `qrtr` trace + modem dump (where firmware exposes `ssr` logs) auto-bundled to `/var/crash/modem-<ts>/` (redacted by log-collect rules, ch.07 §7). Crash-rate dashboard: >1 modem crash/week across dogfood fleet = P0 baseband-stability sprint (not "cosmic rays").

## 16. Roaming design (money + jail risk — explicit by design)

Data-roaming OFF default (ch.07 §3) enforced at MM (`--set-allowed-modes` home-only) AND at bridge (Android `DATA_ROAMING` setting slaved to host toggle — container toggle without host = rejected + explained). New-MCC prompt: banner within 10s of registration change ("Welcome to <country-ish MCC> — roaming stays off. Turn on?") with per-trip "roaming budget nudge" (user-set MB cap, warn at 80% — bill-shock prevention is a feature P1s remember). Inadvertent-roam guard: border-cell hysteresis (2-min dwell before prompt re-fires; no prompt spam on border commutes — tested with recorded cell-change fixture). Charges dispute support: connection log export (timestamps + MCC + bytes, redacted of content — support script §2 names it).

## 17. Dual-SIM Phase-4 design (v1 single-active, §9 — this is the future file, not scope creep)

Hardware-gated: only SKUs with proven dual-standby RF (both IMEIs registered independently in lab). Design sketch (frozen at sketch until v1 ships — no code): host MM multi-modem objects (one per slot), active-data selector in Settings (switch ≤15s with progress), per-SIM ring assignment (Calls shows "SIM 1/2" on every MT screen — misattributed-SIM answers are the classic dual-SIM UX injury), SMS per-SIM sender picker (default = last-used-SIM per thread, shown inline). Android side: `SubscriptionManager` multi-sub populated via bridge (no fake single-sub once hardware does dual — the v1 single-sub lie must be removed, tracked as Phase-4 blocker PHASE4-DSDS-1).

## 18. Carrier acceptance testing (blessing a carrier is a test campaign, not a vibe)

Blessing checklist per carrier/SKU (all green or UNTESTED-bold, ch.07 §11 vocabulary enforced): attach-timing 3 runs (≤90s gate §6), 20/20 calls + 50/50 SMS (Phase-3 gate counts), airplane-recovery ≤60s ×5, 1h soak (§6) + 8h idle (§6), SMSC behaviors (§smsc-doc: normalization + retry + reports-capability recorded), MMS 3×3 (smsc §2), OTP 2 flows (ch.07 verification row), STK basic menu walk (best-effort result recorded), roaming-SIM swap (border fixture where available, §16 hysteresis observed), emergency-status determination (VERIFIED-with-blessing or UNTESTED — §10 protocol). Campaign log (`carrier/<id>/blessing-<date>.md`): tester, SIM SKU, firmware, cell/bands, ambient anomalies (storms affect radio — note them), per-item pass/fail with log links. Re-blessing triggers (prior blessing expires): modem-fw change, our RIL/bridge change touching call/SMS paths, carrier-side VoLTE/CSFB policy change notice, 6-month age (stale blessings re-run abbreviated: attach + 5 calls + 10 SMS + soak — full campaign annually).

## 19. eSIM / LPA future (out of v1 scope per §9 — this section prevents accidental architecture lock-in)

Constraints v1 must respect so Phase-4 eSIM stays possible: modem interface abstraction owns profile-slot concept already (MM `Modem3gpp` profile slots enumerated even where only physical SIM exists — single-slot truthfully reported, API shape forward-compatible), no hardcoded single-ICCID assumptions in bridge schemas (`slot_id` field present in ril-protocol `REG_STATE`/`SMS_RX` from day one — reserved-and-populated, ch.05-bridges/ril §2 extended), SM-DP+ TLS trust store decision deferred (no baked-in carrier root that prejudges the LPA trust model — threat-model §5 row added at Phase-4 kickoff, not now). eUICC presence recorded per SKU in hardware matrix (02 §2 record already has the field — presence noted during REF bring-up even though unused). Deliberately NOT decided: LPA UI ownership (host Settings vs Android EuiccManager bridge), profile-download data accounting (metered-link rules, ch.05 netd §4 pattern will apply), enterprise eSIM provisioning (P3 lane in Phase-4 planning). Undecided-list reviewed at v1 ship (promote to Phase-4 plan or explicitly defer again with date — drift is how eSIM becomes vapor).

## 20. Data-stall detection & recovery (stalls are silent — detection is the feature)

Data stall = registered + bearer "connected" but no user-plane throughput. Host (NM+MM) is the detector and healer; Android side only mirrors state via ril-bridge (never heals independently — dual-healer races cause bearer flaps).

Detection stack (all host-side, polled by `halide-data-watch` daemon, 10s idle / 5s screen-on):
1. Passive: NM connectivity check (`connectivity-check.uri` per SKU, 60s interval) + `qmicli --wds-get-packet-statistics` TX/RX byte deltas. Stall suspect if bytes frozen ±2KB over 60s while bearer state = connected.
2. Active probe (only on suspect): 3× ICMP to carrier DNS + 1× HTTPS HEAD to connectivity URI with 10s timeout. Probe traffic marked `halide-probe` (excluded from user billing counters where carrier API allows; documented per carrier).
3. Modem-state cross-check: `qmicli --nas-get-signal-info` + `--wds-get-packet-service-status`. If RRC = IDLE + DRX normal, stall is bearer-level (recover bearer). If RRC = disconnected while MM says connected, stall is registration-level (re-register path).

Stall classification table:

| Class | Signature | Auto-action | User-visible |
|-------|-----------|-------------|--------------|
| STALL-BEARER | bytes frozen, RRC connected, probe 3/3 fail | NM bearer down → `mmcli -m --simple-connect` re-attach same APN (1 retry), then APN-fallback profile | "Data reconnecting…" ≤30s, no prompt |
| STALL-DNS | ICMP OK, HTTPS fail, DNS latency >5s | rewrite `/etc/resolv.conf` to carrier DNS → fallback 8.8.8.8 only if carrier DNS fails 3× (log fallback — some carriers block third-party DNS) | silent if healed ≤30s |
| STALL-RRC | bytes frozen, RRC disconnected, MM connected | MM re-register (`--3gpp-register-home` or auto), ≤2 attempts | banner if >60s |
| STALL-MODEM | QMI timeout on all commands | escalate to modem-crash ladder (§15), not data-stall path | "Radio restarting" (§15) |
| STALL-CARRIER | attach succeeds but probe fails on all APNs | backoff + notify (likely carrier outage / APN deprec) | "Mobile data unavailable — Wi-Fi suggested" + support export |

Recovery ladder (automatic, ≤3 min total before user prompt):
1. T+0s: freeze Android `DATA_STALL` mirror to `SUSPECT` (bars stay, activity arrows freeze — §14 indicator rule: arrows reflect truth, so frozen arrows + "…" badge, never fake animation).
2. T+0–30s: bearer re-attach (same APN). Success → `RECOVERED-BEARER`, log to `carrier/<id>/stall.log` (timestamp, cell, signal, class, action, healed-Y/N).
3. T+30–60s: APN fallback (secondary APN from `apn.json` fallback list, §21). Success → `RECOVERED-APN-FALLBACK` + flag APN DB for review.
4. T+60–120s: airplane-cycle-equivalent via MM (`modem disable → enable`, not full rproc restart — cheaper, preserves SIM auth). Success → `RECOVERED-REREGISTER`.
5. T+120–180s: escalate — user prompt ("Data stalled. Retry / Switch to Wi-Fi / Export diagnostics") + auto-bundle redacted stall report. Never loop past 180s unattended (battery + carrier-signalling discipline).

Verification: `tests/data-soak.sh` extended with `data-stall-inject.sh` (iptables DROP on wwan0 60s → expect STALL-BEARER → auto-recover ≤90s on restore; QMI-blackhole fixture → expect STALL-MODEM escalation). Gate: 5/5 injected stalls detected ≤60s, 5/5 recovered-or-escalated ≤180s. Stall-rate dashboard: >2 stalls/device-week across dogfood = P1 radio-stability bug (not "carrier weather").

## 21. APN database maintenance (wrong APN = "no data" support ticket #1)

Source hierarchy (first hit wins, all versioned): (1) per-carrier `carrier/<mcc-mnc>/apn.json` blessed entries (highest trust — lab-verified), (2) `mobile-broadband-provider-info` snapshot pinned in manifest (version recorded in MANIFEST.lock, updated ≤90 days), (3) carrier OTA APN push (accepted only if MCC-MNC matches inserted SIM + signature/transport is carrier-authenticated — unauthenticated APN pushes rejected and logged; APN-push-as-attack is a real vector), (4) user manual entry (Settings → Network → APN, always allowed, flagged `user-override` so updates never silently clobber it).

`apn.json` schema (extends §11 profile):

```json
{"mcc_mnc": "310260", "apns": [
  {"name": "default-internet", "apn": "fast.example", "auth": "none",
   "types": ["default", "supl"], "mvno_type": "gid", "mvno_match": "AE",
   "fallback_order": 1, "verified": "2026-05-01", "ims_separate": true},
  {"name": "mms", "apn": "mms.example", "mmsc": "http://mmsc.example",
   "types": ["mms"], "fallback_order": 2, "verified": "2026-05-01"}],
 "db_version": 14, "source": "blessed-lab + mbpi-20260301"}
```

Maintenance cadence: MBPI snapshot review monthly (diff vs pinned — new APNs staged to `carrier/staging/`, never auto-promoted to blessed); blessed-entry re-verify on (a) modem-fw change, (b) carrier notice, (c) stall-log showing APN-fallback recoveries >5/month on that carrier (signal the primary APN rotted). Roaming APNs: same-SIM-different-MCC uses visited-network APN only if blessed for that pair; otherwise data stays off per §16 (no auto-guess on roaming — guessing roams into charges).

Failure modes: MVNO mismatch (APN correct but MVNO-type wrong → attach OK, no data — §8 row; fix is `mvno_match` correction + re-bless); IMS-APN conflation (single-APN carriers where internet+IMS share — record `ims_separate: false` and skip separate IMS attach in §10 ladder step 1); IPv6-only APN (set `ip-type` per entry; test `ip-type=4` vs `6` vs `4,6` explicitly — record which the carrier actually routes, never assume dual).

## 22. Call-quality monitoring (MOS without the lab-coat theater)

Scope: CS voice v1 (VoLTE only where §10 blessed). Metrics collected per call (host-side, redacted — no audio content stored): RSRP/RSRQ at setup + mid-call, codec (`AMR-NB/WB` from QMI voice info), jitter proxy (PCM underrun count from PipeWire + modem-side `qmicli --voice-get-call-info` where exposed), drop cause (`hangup-cause` QMI code mapped to local/remote/radio-fail), setup latency (dial → alerting ms), one-way-audio flag (TX bytes >0 + RX bytes =0 over 5s window or vice versa).

Per-call record (`~/.local/share/halide/calls/<date>.csv`, never committed unredacted): timestamp, duration, direction, RAT, signal-at-setup, codec, setup-ms, drop-cause, underrun-count, stall-flag. Aggregated weekly per blessed carrier into `carrier/<id>/voice-quality.md`: setup-success %, drop %, median setup-ms, underrun-rate, per-scenario split (quiet/street/car/speaker/headset from §4 tuning set).

Quality gates (Phase-3, per blessed carrier): setup-success ≥98% over 50 calls, drop ≤2%, median setup ≤8s CS, 0 one-way-audio in 50 calls. Miss → tuning sprint (gains in `call-gains.conf` → antenna/RF check → modem-fw note → carrier escalation in that order; no modem-fw bump without re-bless per §23).

User tooling: Settings → About → Call quality shows trailing-30-day aggregates (plain language: "42 calls, 2 dropped, usually connects in 5s") + per-call "Report bad call" button (tags last-call record `user-flagged`, attaches redacted radio snapshot — user-perceived quality is ground truth for P1 triage even when metrics look green).

## 23. Modem-firmware upgrade procedure with re-blessing (fw bumps reset trust)

Policy: modem-fw version is a dimension of every carrier blessing (§18). Any fw change expires all blessings on that SKU to `STALE-FW` until abbreviated re-bless passes. No silent fw (fw version shown in Settings → About → Modem, `mmcli -m` firmware revision, recorded in every bug bundle).

Pre-upgrade: (1) record current fw (`qmicli --dms-get-revision` + `mmcli -m` firmware), carrier blessings, stall-rate baseline (trailing 2 weeks), voice-quality baseline; (2) full `persist/efs/modemst` + GPT backup per factory runbook (ch.09 §10 — fw flash without backup = process fail); (3) stage fw package with SHA + vendor release notes + rollback package availability confirmed (no-rollback fw never flashed on dogfood units — lab sacrificial unit first).

Upgrade execution (lab sacrificial unit first, 48h soak before fleet): flash via vendor tool/EDL-or-fastboot path per `hw/<sku>/edl.md` → verify revision changed → re-run bring-up ladder §2 steps 1–6 → abbreviated re-bless per carrier (attach 3 runs + 5 calls + 10 SMS + 30-min soak + airplane-recovery ×2 — §18 abbreviated set) → compare stall/voice baselines (regression >10% = fw-reject candidate).

Re-blessing matrix update: `carrier/<id>/profile.json` gains `modem_fw` field + `blessed_fw` list; `blessing-<date>.md` references fw version explicitly. Rollback: if abbreviated bless fails twice (two clean flashes), roll back fw on the sacrificial unit, file P0 `MODEM-FW-REGRESSION`, notify fleet to hold (OTA hold flag ch.09 §4), escalate to vendor with redacted QMI error set + before/after metrics (vendors fix data with numbers, not adjectives).

Fleet rollout of fw: bundled only in staged OTA (never standalone silent push — ch.09 §4 bake gates apply, rollback-rate >2% halts including fw-driven rollbacks). Release notes name fw version change + re-bless status per carrier (same honesty vocabulary as §11: VERIFIED / STALE-FW / UNTESTED).

## 24. Hotspot, USB-tethering & metered-link operations (sharing the bearer without sharing the bill shock)

Ownership: NetworkManager owns all sharing paths (Wi-Fi hotspot, USB-tethering, single-client v1 gate per §6). Android hotspot toggle is slaved to NM via ril-bridge (container toggle without host bearer = rejected + explained, same doctrine as §16 roaming toggle). v1 limits (binding): 1 hotspot client, WPA2-PSK minimum (open-hotspot option absent by construction — support never debugs an open hotspot hijack), USB-tethering 1 host, concurrent hotspot+USB off (one sharing path at a time — routing-table simplicity is a security control here).

Provisioning: hotspot SSID defaults to `HALIDE-<4-hex>` with per-device random PSK printed once at first-enable (PSK rotation button in Settings; PSK stored in host keyring, never in Android provider mirror). USB-tethering exposes `usb0` via NM shared mode with the same metered flag as the LTE bearer. Battery/thermal guard: hotspot auto-suspends at battery ≤15% (user-overridable once per session with explicit "may drain" confirm) + thermal pause at skin-temp ≥44°C (resume hysteresis 2°C — flapping hotspot at the thermal edge fails the §4 thermal gate, so hysteresis is specified, not tuned later).

Metered-link discipline (extends §6 + ch.05 netd §4 pattern): LTE bearer always reports metered to Android `ConnectivityService` unless the carrier profile explicitly marks unmetered (field `metered_override` in `apn.json` §21, default absent = metered). Hotspot clients inherit metered; large-download guards on both stacks key off the same flag (test: 500MB download from client warns on metered, silent on Wi-Fi-backhaul lab fixture). Data-cap nudge (pairs with §16 roaming budget): user-set monthly MB cap on the LTE bearer, warn at 80%, hotspot auto-off at 100% unless overridden (bill-shock prevention on home networks too — P1s remember this exactly like roaming).

Verification: hotspot 30-min stability (§6 gate) + client-count enforcement (2nd client rejected with message, asserted in `data-soak.sh` hotspot phase) + metered-flag mirror test (Android `NetworkCapabilities.NET_CAPABILITY_NOT_METERED` absent on LTE, present on lab Wi-Fi) + thermal-pause drill (heat-gun-free: force temp via `tests/thermal-spoof.sh` on sacrificial unit only — spoof tool refuses dogfood units by serial allowlist).

## 25. USSD handling design (host-owned sessions, Android MMI-code routing, timeout/error UX)

Ownership restates §1 host-owns-modem with no exception for USSD: the USSD session lives in ModemManager on the host (`mmcli -m N --3gpp-ussd-initiate/respond/cancel` or QMI UIM/voice-USSD path where MM delegates — the path per SKU recorded in `telephony/<sku>/ussd-path.md` because USSD rides different QMI services per baseband and guessing wastes weeks). Android MMI codes (`*100#`, `*#06#`, balance checks) never reach the modem directly: the dialer `CALL` intent with a USSD-shaped string is intercepted by `halide-ril-bridge` (pattern `^[*#].*[#]$` plus `*#06#` IMEI-display special case — IMEI shown from host `qmicli --dms-get-ids` with the §7 redaction banner, never forwarded to the network), translated to an MM USSD D-Bus call, and the session state machine lives host-side (`IDLE → INITIATED → NETWORK-RESPONSE-PENDING → MULTISTEP-AWAITING-INPUT → CLOSED/CANCELLED/TIMEOUT`). Android `onUssdFinished`/`UssdResponse` callbacks are synthesized by the bridge from MM signals — so two Android apps racing USSD get serialized with `USSD_BUSY` on the second (one session per modem is a network fact; the bridge enforces it rather than letting the modem abort both).

Multistep menus (carrier balance trees "reply 1 for data"): inbound `network-notification` text is forwarded verbatim (GSM-7/UCS2 decoded host-side with the §13 PDU discipline — multipart/encoding bugs already solved once for SMS are reused, not reimplemented) to whichever UI initiated (GNOME Calls USSD sheet if host-dialed, Android app callback + mirrored host notification if Android-dialed — both show the same text, single-session truth). Reply input routes back through MM `respond` within the network timeout; session idle 60s without reply → bridge auto-sends `cancel` + user-visible "Session ended (no reply)" — modems left in dangling USSD state reject subsequent call setups on some carriers, so cancel-on-idle is a correctness rule, not politeness.

Timeout/error UX (exact strings committed so support matches docs): `NO-SERVICE` (unregistered — "Can't run codes without signal"), `USSD-BUSY` (session active — "One code at a time — cancel current? [Cancel]"), `NETWORK-TIMEOUT` (no response 90s — "Network didn't answer. Try again — you were not charged for this attempt" only where carrier confirms no-charge; otherwise "check balance SMS" honesty), `MMI-ERROR` (network reject with cause code shown + log link — "Rejected (code 0x…)" beats a bare "failed"), airplane/SIM-pull mid-session → `SESSION-ABORTED` + §15 ladder state (`MODEM_SUSPECT` freezes reply box, doesn't silently drop). STK-initiated USSD (§9 STK best-effort) reuses this machine with `origin=STK` tag (menu text logged redacted §7). Verification `tests/ussd-flow.sh`: `*#06#` offline IMEI-display (no network), live `*100#`-class balance query on lab SIM (record per-carrier result in `carrier/<id>/profile.json` `ussd` field: `VERIFIED-<code>` / `REJECTED-<cause>` / `UNTESTED`), multistep fixture (1→2→cancel walk), 90s-timeout injection (assert cancel + string), airplane-mid-session abort (assert `SESSION-ABORTED` + recovery ≤60s §8 row), dual-initiator race (assert second gets `USSD-BUSY`, first completes).

## 26. Call-forwarding/waiting supplementary services via MM (SS codes without a second master)

Scope: unconditional/busy/no-reply/not-reachable forwarding (CFU/CFB/CFNRy/CFNRc), call waiting (CW), calling-line presentation (CLIR/CLIP query only — CLIR-set gated behind explicit user confirm because hiding caller ID has carrier-charge and abuse implications, documented per carrier), call barring query (set flows documented but disabled v1 pending carrier-acceptance evidence — setting barring with the wrong password locks outbound on some networks; read-only v1 is the safe default, stated). Transport: MM `Modem3gppUssd`/`ModemVoice` supplementary-service D-Bus (`QueryCallForwarding`, `SetCallForwarding`, `QueryCallWaiting`, `SetCallWaiting` where exposed; QMI `voice` SS fallback `qmicli --voice-query-call-forwarding` where MM gaps exist — fallback path per SKU in `telephony/<sku>/ss-path.md`, same discipline as §25 USSD path file). Android `MmiCode`/`GsmMmiCode` for CF/CW (`**21*`, `*43#`, `##002#` erase-all) intercepted exactly like §25 USSD (same regex gate, same single-session serialization — SS and USSD share the modem control channel on many basebands, so they share the bridge lock `ss_ussd_mutex` with 30s deadlock-watchdog that logs + releases + files `SS-DEADLOCK` metric rather than wedging voice).

Host UI (Settings → Network → Call forwarding, GNOME Calls overflow for CW toggle): reads render MM query results with per-rule rows (service-class voice only v1 — fax/data classes hidden, not faked; "not set" vs "unknown (query failed)" distinguished — conflating them causes users to delete forwarding they can't see), writes require PIN→MM where carrier demands (MMI `--password` path, wrong-password error surfaces verbatim, no retry-loop — 3 wrong SS passwords can lock the SS service per carrier policy, so the UI warns before the third attempt). Android-side Telephony `ImsPhone`/`GsmPhone` SS requests are translated, never passed through (single-master §1 restated for SS: an Android SS write that bypassed the bridge would desync the host display — bridge is the only writer, both UIs read MM).

Failure semantics: query-fail shows "Couldn't read settings — try on Wi-Fi off / stronger signal" (SS over IMS vs CS domain matters per §10 — where VoLTE unblessed, SS forced over CS with `domain=CS` logged; where carrier is VoLTE-only data-only v1 §10, SS rows show "unavailable on this carrier combo" instead of fake toggles). `##002#` erase-all requires typed confirm + post-erase re-query proving cleared (optimistic "done" without re-query is how forwarding silently survives — the re-query is the gate). Verification `tests/ss-flows.sh` per blessed carrier: CFU set→query→erase→query cycle (assert round-trip), CW enable/disable round-trip, `##002#` confirm + re-query-cleared, wrong-password path (assert verbatim error + no lockout after 1 attempt + warning copy before 3rd), airplane-mid-query (assert unknown-state, not not-set), Android-dialed `*43#` (assert bridge-translated, host UI reflects within 10s — permission-atomicity §5 ch.05 pattern: both displays agree or the test fails).

## 27. SIM PIN/PUK flows with retry counters (the 3-try fuse before PUK, the 10-try brick)

Authority: host MM owns PIN/PUK state (`mmcli -i <idx>` `sim-properties`: `pin-required`, `retries-remaining` where the modem exposes it — QMI UIM `verify-pin`/`unblock-pin` responses carry retry counts; where a baseband hides counts, the bridge maintains a conservative local counter persisted in `/userdata/.halide/simstate` that only ever under-reports remaining (showing "2 left" when 3 remain is safe; the reverse bricks SIMs — the bias direction is specified). Android `Keyguard`/`TelephonyManager` PIN/PUK prompts are slaved: container PIN dialog input forwarded to MM, never verified locally (no second counter that disagrees — single-counter rule mirrors §1 single-master). First-boot PIN enrollment (ch.05 §8 lockscreen-PIN-mandatory-before-modem rule) sequences before SIM unlock: device lock PIN first, then SIM PIN if `pin-required` (ordering prevents a stolen-device race where modem attaches before the owner lock exists).

Attempt ladder (exact copy, Settings + bridged Android sheet + support script agree): PIN entry shows `N attempts left` (N from modem, or conservative local); wrong PIN decrements with 5s UI throttle (no scripted hammering through the UI — AT/QMI-level hammering additionally rate-limited in the bridge: max 1 verify/2s, excess returns `RATE-LIMITED` locally without touching the SIM); 3rd wrong PIN → `PIN-BLOCKED, PUK required` (modem state asserted via re-query, not assumed from count — some SIMs block at 3, obscure ones at 5; the modem is truth); PUK screen requires PUK + new-PIN + confirm-new-PIN triple (all three validated locally for format before any network touch — malformed PUK never consumes an attempt); PUK wrong decrements the 10-attempt fuse with escalating warns ("5 left" calm → "2 left — STOP and call your carrier" red + support number from `carrier/<id>/profile.json` ` puk_help` field); 10th wrong PUK → `SIM-PERMANENTLY-BLOCKED` (bridge asserts `sim-state: permanently-blocked`, offers only "order replacement" + export-contacts-from-host-copy path — the SIM is a brick, the phone is not; host data and eSIM-roadmap §19 unaffected).

Security/UX guards: PIN/PUK keystrokes never logged (log-collect §7 redaction list extended: 4–8-digit prompt-adjacent buffers scrubbed; `tests/telemetry-off.sh`-style redaction test seeds `123456` near a PIN prompt and asserts absence); PIN stored nowhere (passed MM→modem transiently, zeroed buffer — "remember SIM PIN" checkbox absent by construction v1, enterprise-P3 demand tracked as Phase-4 item with its own threat row, not snuck in); reboot/suspend preserves `pin-required` state (drain §26 ch.05 never auto-unlocks — power-cycle re-prompts; test asserts `mmcli -i` still `pin-required` post-§26-drain); SIM-swap mid-PUK-flow aborts the flow + re-queries new SIM state (stale-PUK-against-new-SIM is the classic brick vector — swap detector is `udev` SIM-gpio + MM `SimChanged`, either fires → abort). Verification `tests/sim-pin-puk.sh` (lab test-SIMs with known PIN/PUK only — never dogfood SIMs; script refuses non-lab ICCID prefix): correct-PIN unlock ≤30s + attach follows (§6 gate), 2-wrong-then-right (assert counter + success), PIN-block path on sacrificial test-SIM (3 wrong → PUK screen + modem-state assert), PUK triple-format validation (bad-format never decrements — assert counter static), swap-abort fixture, reboot-persistence, log-scrub assert.

## 28. Network-selection manual mode UI + PLMN list handling (choosing towers without foot-guns)

Modes (host NM/MM truth, Android `Phone` settings slaved read-mostly): `AUTOMATIC` (default, MM `3gpp-register-auto` — modem picks home/roaming per SIM policy) and `MANUAL:<plmn>` (MM `--3gpp-register-in-operator <mcc-mnc,access-tech>` pinned — survives reboot and airplane-cycle by design, with a 24h "still pinned?" nudge so a travel manual-pick from last month doesn't silently camp a roaming partner at home). Android manual-select taps are translated to host register calls (same doctrine as §§25–26: bridge is the only writer; container toggle without host = rejected + explained per §16 pattern). Scan path: `mmcli -m N --3gpp-scan` (background, 60–120s typical; progress UI with cancellable + "stale list" timestamp — scan results older than 5 min are labeled stale, never presented as live; concurrent scan + active data bearer throttled: scan pauses user-plane ≤30s slices with `SCAN-PAUSE` traffic note so a scan doesn't silently stall §20 stall-detector into a false STALL-BEARER — the two daemons share a `scan_active` flag).

PLMN list rendering (Settings → Network → Choose network): rows sorted available-home → available-roaming-partner → forbidden (`forbidden` greyed with "blocked by SIM/carrier" — selectable only via explicit override-with-warning, logged; selecting forbidden PLMNs repeatedly triggers some carriers' fraud heuristics — the warning says so) → unavailable-cached (last-seen with age, clearly marked). Each row: operator long name (from `mobile-broadband-provider-info` + NITZ long-name, modem numeric `mcc-mnc` always shown alongside — names lie on border cells, numbers don't), access techs seen (`LTE/5G-NSA/UMTS/GSM` per scan record), roaming cost hint (home vs roaming badge from §16 MCC logic; roaming-manual-select additionally requires the roaming data-off acknowledgment unless data-roaming already on — money-guard composition, not duplication). Forbidden-list reset ("unblock all networks") exposed with confirm (MM `--3gpp-set-forbidden-...` where supported; unsupported-SKU path documented as gap, not faked).

Failure semantics: register-reject causes mapped to copy (cause 13/15 roaming-not-allowed → "This SIM can't use <plmn> here" + suggest automatic; cause 17 network-failure → retry once + §15-ladder cross-check; timeout 120s → revert to automatic + `MANUAL-REVERTED` journal + banner — a manual pick that leaves the phone camped-nowhere is worse than automatic roaming; the revert is the safety net). Border-cell hysteresis (§16) composes: manual pin disables the new-MCC prompt for the pinned MCC (user chose it — stop asking) but keeps the roaming-budget nudge (money honesty survives manual mode). Verification `tests/plmn-select.sh` (lab callbox with 2 fake PLMNs + forbidden fixture; never live-network brute-force scanning — carrier-etiquette rule): automatic attach (§6 gate), scan completes ≤180s with both PLMNs listed + numeric codes, manual pin to PLMN-B (assert camp + survive airplane-cycle + 24h-nudge scheduled), forbidden-select warning + logged override, reject-cause-13 fixture (assert copy + automatic-suggest), timeout fixture (assert revert-to-auto + banner), stale-list label (assert >5min scan shows "stale").

## 29. Modem audio path switching state machine (handset/speaker/BT/USB-C — one path at a time, always named)

Single-path invariant (extends §4 + ch.04 proxy + ch.05 audio-safe): exactly one active uplink/downlink route per call; transitions are break-before-make with 50–150ms crossfade (no hot-mic double-route, no 300ms dead-air that reads as a drop — both bounds asserted in test). Paths enumerated per SKU (`audio/<sku>/routes.conf`: `HANDSET` (earpiece+mic), `SPEAKER` (loudspeaker+top-mic with AEC ref), `BT-SCO` (HFP via host BlueZ §12 — `hsphfpd` AG, SCO link params logged), `USB-C` (USB-audio headset where `hw/<sku>` exposes it; absent-SKU hides the row, never shows a dead toggle), `WIRED-3.5MM` where jack exists). Android `AudioManager.setSpeakerphoneOn` / `setBluetoothScoOn` / wired-headset plug intents are translated to host route-switch requests (bridge proposes, host disposes — host mixer owns `call-gains.conf` per-path gains from §4 tuning set; Android-side DSP effects bypassed always, ch.05 audio-safe default extended to normal path: one EQ, host-side, measured).

State machine (`halide-call-audio`, host daemon alongside `halide-audio-daemon` ch.05 §9 detail; states `IDLE → ROUTE:<path> → SWITCHING:<from>→<to> → ROUTE:<path>` with `SWITCHING` bounded 500ms watchdog → on expiry revert to pre-switch route + `AUDIO-ROUTE-FAIL` metric + user banner "Couldn't switch audio — still on <path>"):

| Event | In `ROUTE:HANDSET` | In `ROUTE:SPEAKER` | In `ROUTE:BT-SCO` | In `ROUTE:USB/WIRED` |
|---|---|---|---|---|
| User taps Speaker | →SWITCHING→SPEAKER (crossfade, AEC ref re-point) | noop (idempotent tap, no glitch) | →SWITCHING→SPEAKER + SCO suspend (link held 10s for fast switchback) | →SWITCHING→SPEAKER |
| BT connects mid-call | banner "Headset found — switch? [Switch]" (never auto-grab — auto-grab routes grandma's call to the car; the manual-confirm is the UX rule) | same banner | auto-route (already BT — adopt new device with 150ms fade) | same banner |
| BT disconnects mid-call | — | — | →SWITCHING→HANDSET fallback + "Headset lost — back to earpiece" (fallback is HANDSET, never SPEAKER — speaker-fallback in public is a privacy injury) | — |
| Wired/USB plug | →SWITCHING→WIRED (plug wins over handset silently — physical intent is unambiguous) | →SWITCHING→WIRED | hold BT + banner "Wired plugged — switch? [Switch]" (two externals = ask, one external = obey) | adopt new jack/USB (last-plugged wins, logged) |
| Wired unplug | — | — | — | →SWITCHING→pre-plug route (stack memory, 1-deep — unplug restores, never drops to IDLE mid-call) |
| Modem crash (§15) | freeze route (hold gains, mute 200ms) → re-apply post-ladder (route survives radio restart — §15 replay includes route) | same | same + SCO re-establish (SCO setup ≤3s post-recovery or fallback HANDSET + banner) | same |

Gain/effects per transition: per-path gains from `call-gains.conf` applied atomically with route (no 1s loud-then-quiet — gain+route single ALSA/pipewire transaction, underrun counter §22 ch.07 observed across every switch in test); EchoRef re-pointed per path (speaker-AEC ref ≠ handset ref — wrong-ref echo is the §4 PESQ-killer, asserted by `pw-top` + loopback capture diff in test); privacy guard: `ROUTE:SPEAKER` shows persistent in-call banner + notification-dot (both stacks — §14 indicator-honesty extended to audio: bystanders and screenshots both reveal speaker state).

Verification `tests/audio-route.sh` (5 scripted environments from §4 quiet/street/car/speaker/headset reused): full transition matrix above (each cell asserted: route applied ≤500ms, no double-route via mixer-dump, gains match `routes.conf`, underrun delta ≤3), BT-loss fallback-to-handset (assert never-speaker), unplug-restore, crash-during-call route-hold (inject §15 rproc fixture mid-call → assert re-applied post-ladder), crossfade bounds (50–150ms via loopback envelope — below sounds like a cut, above sounds like a drop; both fail).

## 30. QMI message retry/backoff table (timeout per service, QMUX transaction IDs, audit log)

All host→modem control traffic rides QMUX over QRTR (`/dev/qrtr`); ModemManager owns the socket, `halide-ril-bridge` and `halide-data-watch` never speak QMUX directly (single-speaker rule extends §1 single-master to the wire — two QMUX speakers interleave transaction IDs and both lose). This section pins the timeout/retry contract per QMI service so "modem didn't answer" becomes a classified, counted, audited event instead of a hang followed by a reboot. Timeouts below are host-side abandonment times (stop waiting, free the txn slot, classify); they are not modem-side cancellations (QMI has no universal cancel — a late response after abandonment is matched by txn ID and dropped with an `LATE-RESPONSE` audit row, never applied to state).

QMUX transaction-ID discipline (1-byte per service instance, 0 reserved, 1–255 rolling — collisions under concurrency are the classic dual-speaker injury this design prevents): MM maintains one pending-map per `(service, client-id)` tuple (`txn_id → {qmi_msg_id, sent_mono_us, timeout_ms, retry_n, idempotent_bool, origin}`); new requests take the lowest free ID (scan 1–255, never blind-increment — blind increment wraps into a still-pending ID under load and misattributes a VOICE answer to a NAS question); response with unknown/expired txn ID → `STALE-TXN` counter + drop (never route to the newest waiter — misrouting a `WDS start-network` handle to the wrong bearer leaks a bearer that nobody tears down); wrap stall guard: if 0 free IDs for >5s (service wedged, typically WDS after carrier detach), the service client is re-allocated (`qmicli --wds-noop` client-release + re-get-client) and all pending classified `TXN-EXHAUSTED` with the §15 ladder consulted (exhaustion + QRTR hello alive = client leak, re-alloc; exhaustion + hello dead = `MODEM_SUSPECT`, escalate, don't spin). Max 8 concurrent txns per service instance (backpressure: 9th request queues ≤2s with `QMI-QUEUED` metric, then rejects `QMI-BUSY` to the caller — callers must handle BUSY by backing off, not by opening a second client).

Timeout/retry table (normative — `telephony/qmi-policy.conf` carries these numbers; any MR changing one cites the carrier evidence):

| QMI svc | Example msgs | Timeout | Retries / backoff | Idempotent? | On-final-fail |
|---|---|---|---|---|---|
| DMS (`0x02`) | `get-ids`, `get-revision`, `get-time` | 5s | 2×, 1s+2s linear | yes (reads) | `MODEM_SUSPECT` if `get-ids` fails twice (DMS is the heartbeat — §15 ladder, not data-stall path) |
| NAS (`0x03`) | `get-signal-info`, `register-home/auto`, `get-serving-system`, `scan` | 10s (30s scan, 120s register) | register: 2× (10s, 30s exp); signal-poll: 0 retries (stale signal worse than no signal — drop, keep last-good with age label §14) | register NO (network-side state; retry only after `get-serving-system` proves idle) | register-fail → cause-code map (§28 PLMN copy) + `STALL-RRC` cross-check (§20) |
| WDS (`0x01`) | `start/stop-network`, `get-packet-status`, `get-stats` | 15s start, 5s status/stats | start: 1 retry same-APN then APN-fallback (§20 ladder T+30); stop: 3× 2s (leaked bearers bill — stop retries harder than start) | start NO (double-start double-bearer — guard with `get-packet-status` pre-check) | start-fail ×2 → `STALL-CARRIER` + user prompt path (§20 T+120) |
| VOICE (`0x09`) | `dial`, `hangup`, `get-call-info` | 8s dial (network alerting may lag — dial-timeout ≠ call-failed; confirm via `get-call-info` before declaring) | dial: 0 auto-retries (double-dial double-calls grandma — user confirms redial, §15 queued-dial rule) | NO | dial-timeout → `CALL-UNKNOWN` state (query call-info 2×, then banner "Call status unknown — check", never fake success/fail) |
| UIM (`0x0B`) | `verify-pin`, `unblock-pin`, `get-card-status` | 10s (SIM crypto slow on old UICCs) | 0 auto-retries at QMI layer (PIN-attempt counting §27 lives above — a QMI retry that re-sends `verify-pin` consumes TWO attempts for one user tap and bricks SIMs; timeout → query `get-card-status` to learn whether the first attempt landed) | NO | verify-timeout → `PIN-UNKNOWN` (re-query status, show "Checking SIM…" not "wrong PIN") |
| IMS (`0xE3`/`PDC`) | `ims-status`, `pdc-list/get` | 10s | 1× 5s | yes (reads) | §10 ladder step-1 stop rule (no attach = stop, don't hammer PDC — hammering PDC on carrier-locked fw triggers throttling that looks like a modem bug) |
| SMS/WMS (`0x05`) | `send`, `ack`, `list`, `delete` | 12s send, 5s list/delete | send: §31 state machine owns retries (not this table — single owner; this row only sets the per-attempt 12s) | send NO | §31 `WAIT-RP-ACK` timeout path |
| SS/USSD via VOICE+UIM | `orig-ussd`, SS query/set | 90s USSD-network-wait (§25), 15s SS query | USSD: 0 (network owns the clock); SS query: 1× 5s | SS-query yes; SS-set NO | §25 `NETWORK-TIMEOUT` / §26 unknown-state strings |

Backoff shape (all retries): exponential `base*2^n` capped per-row + ±25% jitter (three dogfood units retrying a flaky cell without jitter synchronize into a signaling storm — jitter is a network-citizenship rule, logged in `qmi-audit.log` as `backoff_ms` so carrier-escalation bundles prove politeness); total budget per user-visible operation ≤180s (same ceiling as §20 data ladder — past 180s the user decides, not the daemon); airplane/SIM-pull/modem-crash during backoff aborts the schedule immediately (`ABORTED-RADIO-LOST`, no zombie retries after rproc restart — post-ladder re-issue is a NEW audit chain with `parent_id` link, never a resumed timer).

Audit log (`/var/log/halide/qmi-audit.log`, rotated 5×10MB, redacted per §7 — no IMSI/IMEI/ICCID/call-numbers/SMS-content; phone numbers hashed `sha256(msisdn+salt-rotated-daily)` for correlation without retention): one JSON row per attempt `{"ts_mono_us","svc","qmi_msg","txn","client","attempt_n","timeout_ms","backoff_ms","result":"OK|TIMEOUT|QMI-ERR-<code>|STALE-TXN|ABORTED-<cause>","latency_ms","parent_id","origin":"mm|bridge|data-watch|ussd|ss"}`. `halide-qmi-report --since 24h` emits per-service timeout-rate + p95 latency + top QMI error codes (feeds §22 voice-quality `setup-ms` + §20 `stall.log` cell correlation — a WDS-timeout spike preceding STALL-BEARER cluster is one incident, not two). Redaction test: `tests/qmi-redact.sh` seeds a fake IMSI adjacent to a DMS response in the log pipeline and asserts absence (same pattern as §27 PIN-scrub test — redaction tests are executable, not policy prose). CI fixture (`tests/qmi-stall-inject.sh`): QMUX blackhole proxy (responses delayed 2× timeout) asserts every row above classifies correctly (DMS→SUSPECT, WDS-start→fallback, VOICE-dial→CALL-UNKNOWN, UIM-verify→PIN-UNKNOWN with counter static) — 6/6 to pass; any misclassification (e.g. dial auto-retried) fails the suite with the audit diff.

## 31. SMS concatenation + retry state machine (TP-MR, RP-ACK, storage-full handling)

Concatenation and retry live host-side in ModemManager + `halide-smsd` (thin policy daemon beside the bridge — Chats and Android intents both submit to it; nobody hand-crafts TP-DUs twice). Encoding/segmentation follow 3GPP 23.040; the modem's WMS `send` carries already-segmented RP payloads (host segments, modem sends — so UDH correctness is testable without a cell, and the stock-phone oracle §13 judges our bytes, not our intentions).

Reference numbering (TP-MR + UDH concat ref — two numbers, different scopes, confused implementations corrupt threads): GSM 03.40 `TP-Message-Reference` (per-submit increment 0–255, host counter persisted in `/userdata/.halide/sms-mr` so reboot doesn't reuse an MR the network still holds — MR reuse within the validity window merges delivery reports across messages); concatenated UDH reference (8-bit IEI `0x00`: ref 0–255 + `total` + `seq`; 16-bit IEI `0x08`: ref 0–65535 — v1 uses 16-bit refs always (8-bit ref collision across two long threads inside one hour is a real thread-merge injury; 16-bit random-per-message from `getrandom()`, recorded in the send record for report correlation)). Segmentation: GSM-7 160→153 chars/seg (UDH steals 7), UCS2 70→67 (CJK/emoji path — never downgrade to GSM-7 lossy transliteration to fit one seg; two honest segs beat one mojibake seg), 8-bit data (ringtones/OTA — rejected v1 with `UNSUPPORTED-PAYLOAD`, logged, not misencoded). Max 5 segs outbound v1 (longer → UI warns "very long — send as MMS?" with MMS handoff button; inbound accepts ≤10 segs, 60s reassembly window per §13, duplicates by PDU-hash dedupe BEFORE UDH merge (dedupe-after-merge double-counts retransmitted seg 1 as a new message)).

Send state machine (per message-ID, states persisted across `halide-smsd` restart — a reboot mid-send resumes in `RETRY-WAIT`, never silently drops nor double-sends without re-confirm):

```
SUBMITTED → SEGMENTED → (per seg: RP-SEND → WAIT-RP-ACK) → ALL-ACKED → WAIT-DR(optional) → DONE
   │            │              │ RP-ERROR/TIMEOUT → RETRY-WAIT → RP-SEND (≤N, backoff)
   │            │              └ STORAGE-FULL(remote-SMSC-full) → HELD-SMSC-FULL → RETRY-WAIT(long)
   │            └ ENCODE-FAIL → FAILED-PERMANENT (mojibake refused, user shown exact char)
   └ LOCAL-STORAGE-FULL → HELD-LOCAL-FULL → (after free) → SEGMENTED
```

Per-leg semantics: `RP-SEND` issues one WMS send per segment with its own 12s QMI timeout (§30 row — the state machine owns the retry decision, the QMI layer only reports); `WAIT-RP-ACK` accepts `RP-ACK` (seg accepted by SMSC — advance) vs `RP-ERROR` + cause (classify below, never blanket-retry); `ALL-ACKED` means SMSC holds all segs (user sees single ✓ — per-seg checkmarks hidden, per-seg failures retried silently without user-visible flap); `WAIT-DR` only where sender requested delivery reports (Chats 2FA thread default-on, broadcast threads default-off — DR traffic on every group thread annoys carriers; `RP-ACK ≠ delivered` copy committed in UI ("Sent — waiting for delivery") so users learn the two-checkmark truth). Delivery-report correlation: `TP-MR` + destination + concat-ref tuple (MR alone collides after 256 sends — the tuple never does; reports matched within validity-period + 24h grace, late reports logged `LATE-DR` not applied to a recycled MR).

Retry/backoff table (per segment; message-level abort when any seg exhausts):

| RP-ERROR cause / event | Class | Retries | Backoff | User-visible |
|---|---|---|---|---|
| Timeout 12s, no RP-ACK/ERROR | `RETRY-NET` | 3 | 10s, 60s, 300s exp | silent ≤60s, "Sending…" spinner, then "Retrying" |
| Cause 41 temporary-failure / 42 congestion | `RETRY-NET` | 3 | 30s, 120s, 600s (carrier asked for patience — jitter §30 mandatory) | "Network busy — retrying" after 2nd |
| Cause 111 protocol-error / 95 invalid-msg / 50 requested-facility-not-subscribed | `FAIL-PERMANENT` | 0 | — | exact copy ("Not subscribed for <type>" + support link, never bare "failed") |
| Cause 22 memory-capacity-exceeded (SMSC full) | `HELD-SMSC-FULL` | hold 1h, then 3× hourly | 1h hold (SMSC-full hammering blacklists the sender on some carriers — the hold is politeness with teeth) | "Carrier inbox full — will retry automatically" |
| Local ME/SM storage full on receipt path | `HELD-LOCAL-FULL` | hold until free + 1 auto-resume | — (see storage-full below) | "Phone storage full — oldest messages protected, delete to receive" |
| Airplane/radio-lost mid-send | `HELD-RADIO` | hold until `MODEM_SUSPECT` clears (§15) | resume on re-register (segments already RP-ACKed never re-sent — resume bitmap persisted) | "Will send when signal returns" (queued ≤30s dial-twin §15; SMS >60s old needs user confirm per §15 stale-text guard) |

Inbound storage-full handling (the receive path rots first — senders retry, receivers silently lose): preferred storage `ME` (modem equipment) with `SM` (SIM) overflow where `AT+CPMS` exposes both (path per SKU in `telephony/<sku>/sms-store.md` — some basebands lie about SM capacity and report 30 slots with 10 usable; usable count measured per SKU with a fill-fixture, committed, never datasheet-copied). Watermarks: `USED≥80%` → background trim (delete host-acked read inbound segs already merged + mirrored to Chats/Android (safe-delete set — unread/unmirrored never auto-deleted); `USED≥95%` → user banner + auto-request `RP-ACK` with `memory-full` flag semantics where WMS exposes (network holds instead of discarding — holding beats losing); `100%` → inbound held at SMSC (network retries per validity period) + bridge mirrors `SMS-STORAGE-FULL` to Android (`SmsManager` result `RESULT_NO_MEMORY`, tested — fake-success here loses 2FA codes users never know they missed). Trim audit (`halide-smsd --trim-log`): every auto-delete row `ts,msg_id,mr,dir,age_days,read_bool,mirrored_bool` (user disputes "you deleted my code" answered with the row, not prose). SIM-full special: SM-full with ME-free → move inbound to ME automatically (CPMS shuffle logged); ME-full + SM-full → banner copy above + Chats thread pinned "storage full" until below 90% (hysteresis — 99%-flapping banners train users to ignore them).

Worked example (300-char GSM-7 message, 2 segs — the §13 3×300-char gate's unit): text 300 chars → seg1 153 + seg2 147 (UDH 6 bytes each, IEI `0x08` ref `0x4A2F`, total 2); `TP-MR=0x2C` (next persisted counter); RP-SEND seg1 → `RP-ACK` in 1.8s; RP-SEND seg2 → timeout 12s (`RETRY-NET` attempt 1, backoff 10s) → re-send same `TP-MR`+same UDH ref (identical bytes — SMSC dedupes if the first actually landed; new-ref-on-retry creates ghost duplicates, forbidden) → `RP-ACK` in 2.1s → `ALL-ACKED` (user ✓ at 26s with "Retrying" shown 12–24s) → DR arrives 40s later matching `(MR=0x2C, dest, ref=0x4A2F)` → `DONE` (✓✓ "Delivered"). Audit rows (7: 2 sends + 1 timeout + 1 retry + 2 ACKs + 1 DR) in `halide-smsd` journal with the §30-style JSON (same `parent_id` chain as QMI audit — end-to-end traceability from Chats tap to DR without content in logs). Stock-oracle check (§13): receive both segs on the lab stock phone, assert single merged bubble + identical text hash (UDH order-independence proven by delivering seg2-first in one of the three runs — networks reorder, tests must too).

Verification `tests/sms-concat-retry.sh` (lab SIMs + callbox where available; live-carrier runs labeled per-carrier in `carrier/<id>/profile.json` `sms_concat` field): 3×300-char each direction (assert merged-hash + single-bubble + ≤5-seg rule), seg2-first reorder fixture (assert merge), RP-ERROR-111 fixture (assert `FAIL-PERMANENT` copy, 0 retries in audit), SMSC-full-22 fixture (assert 1h hold, no hammering — audit shows exactly 1 attempt/hour), local-full fixture (fill ME to 100% → inbound held → free 5 slots → auto-resume + `RESULT_NO_MEMORY` mirrored pre-free), reboot-mid-send fixture (kill `halide-smsd` in `WAIT-RP-ACK` → restart → resumes without duplicate on the stock oracle (SMSC-dedupe via identical-ref proof)), MR-persistence (reboot → next MR = previous+1, asserted from `/userdata/.halide/sms-mr`).

## Verification (Phase-3 telephony gate)

- [ ] 20/20 MO+MT calls (5 min), 50/50 SMS, airplane recovery ≤60s, 1h data stable — per blessed carrier/SKU.
- [ ] Emergency routing verified or explicitly flagged untested per build.
- [ ] Redacted log bundle + perf comparison vs stock archived.
- [ ] IMS attempt log + fallback label published per carrier (no silent voice gaps).
- [ ] HFP 10-min + A2DP 30-min + reconnect ×5 pass on reference headset.
- [ ] OTP auto-fill demonstrated for 2 flows (redacted).
- [ ] Data-stall injection 5/5 detected ≤60s, recovered-or-escalated ≤180s.
- [ ] APN DB version recorded; no user-override clobbered by update.
- [ ] Voice-quality gates met per blessed carrier (setup ≥98%, drop ≤2%, 0 one-way-audio/50).
- [ ] Modem-fw version in About matches profile.json blessed_fw; stale blessings flagged.
- [ ] Hotspot single-client enforced; metered flag mirrors to Android; thermal-pause drill passes.
- [ ] Stall/voice baselines archived per blessed carrier before any modem-fw flash.
- [ ] USSD flows green (IMEI offline, live balance query recorded, multistep + timeout-cancel + race-BUSY + airplane-abort).
- [ ] SS round-trips green (CFU/CW set→query→erase, ##002# re-query-cleared, wrong-password warning, Android-dialed *43# mirrored ≤10s).
- [ ] SIM PIN/PUK lab-SIM suite green (counters conservative, PUK triple validated pre-touch, swap-abort, reboot-persistence, log-scrub).
- [ ] PLMN callbox suite green (scan ≤180s, manual pin survives airplane-cycle, forbidden warned, reject-13 copy, timeout reverts to auto).
- [ ] Audio-route matrix green (all transitions ≤500ms, crossfade 50–150ms, BT-loss→handset-never-speaker, crash-hold re-applied).
- [ ] Emergency routing verified or explicitly flagged untested per build.
- [ ] Redacted log bundle + perf comparison vs stock archived.
- [ ] IMS attempt log + fallback label published per carrier (no silent voice gaps).
- [ ] HFP 10-min + A2DP 30-min + reconnect ×5 pass on reference headset.
- [ ] OTP auto-fill demonstrated for 2 flows (redacted).
- [ ] Data-stall injection 5/5 detected ≤60s, recovered-or-escalated ≤180s.
- [ ] APN DB version recorded; no user-override clobbered by update.
- [ ] Voice-quality gates met per blessed carrier (setup ≥98%, drop ≤2%, 0 one-way-audio/50).
- [ ] Modem-fw version in About matches profile.json blessed_fw; stale blessings flagged.
- [ ] Hotspot single-client enforced; metered flag mirrors to Android; thermal-pause drill passes.
- [ ] Stall/voice baselines archived per blessed carrier before any modem-fw flash.

Next: `08-security-verified-boot-crypto.md`.
