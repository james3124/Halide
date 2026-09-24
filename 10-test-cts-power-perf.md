# 10 — Testing: CTS/VTS, Power, Performance & Dogfood
**Budget: 50,000 chars · All phases · Owner: QA · Rule: numbers or it didn't pass**

## 1. Test pyramid

- **Unit/presubmit (VIRT):** kernel selftests (`kselftest`), bridge unit tests (`pytest`), sepolicy neverallow, AppArmor compile, fuzz smoke.
- **Integration (QEMU/Cuttlefish + nightly REF-A):** boot sequence timings, `service list`, permission sync, VPN egress, composer screenshot diff.
- **Hardware (lab):** radio/call/SMS/data, camera, GNSS, audio loop, suspend residency, thermal, OTA rollback, 7-day dogfood.
- **Compliance subset:** CTS/VTS/GTS modules that can pass without GMS (record allowlist; never claim full CTS).

## 2. CTS/VTS/GTS scope (honest subset)

Run and archive (pass-required subset in `tests/cts-allowlist.txt`): `CtsOsTestCases`, `CtsPermission*`, `CtsKeystore*`, `VtsHalAudio*`, `VtsHalCameraProvider*`, `VtsHalSensors*`, `VtsHalPower*`, `VtsHalHealth*`, `VtsHalVibrator*`. Informational-only: telephony IMS, DRM L1, biometric. GTS: skip (no GMS). Publish results per release with device fingerprint + patch level.

## 3. Power lab (Phase-3 gate depends on this)

Setup: programmable PSU + USB-PD meter logging current at 1Hz, same ambient 23±2°C, same cell/band or RF-shield + callbox where available. Scenarios: overnight suspend (8h, SIM+Wi-Fi on), 1h browsing SOT, 30-min call, 30-min hotspot, video 30 min. Metrics: suspend residency (`/sys/power/rpm_stats` + `wakeup_sources` top-10), modem DRX state, display duty. Gate: standby drain within 2× stock; document delta table per SKU (no hand-waving).

`halide-power top` (our tool): merges `wakeup_sources`, `batterystats`, ModemManager sleep state, PipeWire stream states into one screen — built in Phase 2, required for Phase-3 triage.

## 4. Performance & thermal

- Boot ≤45s cold; app cold-start ≤2× stock (measure 10 launches, median).
- Scroll jank <5% missed vsync (Perfetto + `frame_timeline`).
- Thermals: 30-min video + LTE must not hard-throttle below 70% clocks; skin temp ≤45°C (report only, no medical claims).
- Storage: `fio` rand-read/write vs stock; `fstrim` weekly timer verified.

## 5. Dogfood protocol (7-day gate)

10 testers × 7 days, daily form (reboots, app crashes, missed calls/SMS, battery EOD%, photos taken OK?). Failure = any unsolicited reboot, missed MT call/SMS, or data detach requiring manual recovery. Two failures across fleet = gate failed, root-cause week, re-run. Logs: redacted bundles auto-uploaded on consent + `ramoops` on crash.

## 6. Regression & flake policy

Quarantine list (`tests/quarantine.txt`) with bug ID + expiry ≤30 days; quarantined tests still run informationally. No test deleted without replacement. Flake rate >5% over 50 runs = P1 bug, not "infra issue".

## 7. Lab inventory & harness (concrete)

Minimum lab (per ch.02 procurement + this): 2× REF-A + 2× REF-B labeled units, 1 programmable PSU (e.g., Korad-class + USB-PD meter with 1Hz logging to CSV), 1 thermal camera (shared OK), 1 RF-shield bag, 1 reference stock phone (same SKU, stock ROM — the oracle for perf/power/camera comparisons), UART rigs per unit, 1 callbox or cooperative carrier SIM pair, USB-C cable set (C-C + C-A, both orientations labeled — orientation bugs are real, ch.03 §15).

Harness scripts (all in `tests/`, all with `--redact` for committed logs): `boot-timing.sh` (fastboot reboot → parse `systemd-analyze` + `logcat -b events boot_progress` → CSV: firmware/ABL/kernel/systemd/container/app-ready columns), `suspend-stress.sh` (ch.03 §17, extended with composer + modem up), `call-loop.sh` (MO/MT alternating with audio-record + hangup-cause log), `sms-loop.sh` (multipart + delivery reports + dedupe check), `data-soak.sh` (iperf 1h + detach detector), `camera-burst.sh` (20 stills + EXIF + hash + green-frame detector via histogram), `gnss-track.sh` (NMEA TTFF + 15-min walk/drive track vs stock GPX overlay), `ota-rollback-test.sh` (flash bad slot → assert auto-rollback + report exists), `vpn-leak.sh` (flap VPN 10×, assert container egress fails closed every time), `permission-sync.sh` (grant/revoke ×20 both directions, 0 desync).

Every script: exit 0 = pass with `PASS` + numbers; exit 1 = fail with `FAIL` + log path; exit 2 = infra-flake (runner, cable, lab power — counted separately, never silently retried into green; 3 infra-flakes in a row pages lab owner).

## 8. Power methodology (numbers, not vibes)

PSU wiring: phone battery leads bypassed ONLY on sacrificial unit with battery eliminator (never on dogfood units — fuel-gauge behavior differs); dogfood units measured via USB-PD meter + `upower`/`health` cross-calibration (record calibration offset per unit in `power/<sku>/calibration.md` — meters lie by 2–5%, document the lie).

Scenarios (each: 3 runs, same ambient 23±2°C, same cell/band or shield+callbox, airplane-baseline subtracted): overnight suspend 8h (SIM+Wi-Fi on, BT off — the gate), browsing SOT 1h (scripted page cycle, 200 nits measured with lux meter — brightness unmatched invalidates the run), voice call 30 min (earpiece, no BT), hotspot 30 min (1 client, 100MB transfer), video 30 min (720p local file, no network confound), camera 10-min burst (worst-case thermal).

Metrics per run: mean/median current, suspend residency % (`/sys/power/rpm_stats` + `wakeup_sources` top-10 diffed vs stock-approximate where measurable), modem DRX/RRC state histogram (from `qmicli --nas-get-tx-rx-info` samples), display duty %, skin temp (thermal camera spot at SoC + battery), EOD battery % on dogfood units. Gate table (`power/<sku>/results.md`): HALIDE vs stock per scenario with delta % + verdict (PASS if within envelope from ch.02 §6 / ch.01 DoD 2× standby rule).

`halide-power top` spec (Phase-2 build, Phase-3 required): single screen merging host `wakeup_sources` (top-8 by active time), Android `batterystats` top consumers, MM sleep state, PipeWire active streams, composer present-rate — refresh 2s, `--record 8h` CSV mode for overnight runs. Built by Platform with QA acceptance (QA must triage one real power bug with it before gate counts).

## 9. CTS/VTS execution detail

Runner: `atest`/`vts-tradefed` against REF-A `userdebug` (never `eng` — eng SELinux permissiveness fakes passes; CI asserts `getenforce` Enforcing before suite start). Allowlist (`tests/cts-allowlist.txt`, pass-required) vs watchlist (informational, tracked but non-blocking: IMS telephony, DRM L1, biometrics, NNAPI vendor): every allowlist entry has module name + min pass count + known-flake annotation; watchlist entries have bug IDs. Results: `cts-results/<date>/` (full XML + summary MD with fingerprint + SPL + kernel SHA) committed per release; regressions vs previous release block (diff script, not eyeballing).

Flake adjudication: fail → rerun once on same build; pass-on-retry → quarantine entry (bug + 30-day expiry, ch.10 §6) + still counts as non-green for release notes honesty ("X/Y pass, Z quarantined-flake"). No silent green.

## 10. Dogfood operations (fleet discipline)

Fleet: 10 testers (mix P1 pragmatists + P2 hackers — pure-hacker fleets miss normie bugs), each with labeled unit + spare cable + printed emergency-rollback card (recovery key combo + sideload number). Daily form (2 min, phone-first): reboots (count + time), app crashes (which), missed/incoming call+SMS tally, EOD battery %, photos OK?, one-line "worst thing today". Missed daily = ping; 2 missed = check-in call (silent testers hide gateway bugs).

Failure taxonomy: P0 (unsolicited reboot, missed MT call/SMS, data detach needing manual recovery, thermal shutdown, crypto-erase scare) = gate fail immediately, root-cause week, fleet re-run; P1 (app crash >2/day, camera miss, GNSS >5 min, hotspot drop) = 3+ across fleet fails gate; P2 (jank, icon wrong, translation) = backlog with severity vote. Two P0s OR five P1s across the 7 days = gate failed, no negotiation (the rule is written here so release-day pressure can't bend it).

Log pipeline: redacted bundles auto-upload on Wi-Fi with consent toggle (Settings → Dogfood → Share diagnostics); crashes include ramoops + `tombstone` + `batterystats` slice; QA triages within 24h with `NEEDS-INFO`/`DUPE`/`NEW-BUG` labels; weekly bug-review with Arch (30 min, fixed agenda: new P0/P1, quarantine expiries, gate readiness vote).

## 11. Flake triage runbook (flakes are bugs with a different hat)

Triage within 48h of first quarantine nomination: (1) reproduce-rate measurement (50 runs, dedicated runner, no code change — rate + confidence recorded), (2) classify: timing-assumption (fix the wait: poll-with-deadline, never raise sleep — raised sleeps are tech debt with interest), order-dependence (test isolation failure — fix the leak, not the order), resource-contention (lab runner shared — pin resources, record), real-product-race (file P0/P1 against product, test stays quarantined as regression-net), (3) fix + de-quarantine with 50-green streak (streak resets on any fail — no "mostly green"). Quarantine cap: 5 tests max per suite (6th quarantine request forces fixing-or-deleting an existing one first — the cap is the anti-rot mechanism). Monthly flake-review: rate trends per suite, top-3 flakiest owners named (kindly, publicly — accountability without blame).

Infra-flake (exit 2, ch.10 §7 harness contracts) tracked separately: cable swaps, PSU brownouts, runner disk-full — each gets a lab-fix issue (label `lab-infra`) with MTTR recorded; 3 same-cause infra-flakes in a month = lab P1 (fix the lab, not the tests).

## 12. Perf-footnote enforcement (numbers without context are marketing)

Every perf/power number committed anywhere (release notes, MR descriptions, chat claims) must link a footnote set: unit label, firmware SHAs, ambient, cell/band-or-shield profile, brightness nits, run count + median-vs-mean choice stated. `scripts/perf-footnote-lint.sh` greps committed perf tables for footnote markers (`[^fn-]` refs resolving to a footnotes block) — tables without footnotes fail CI with a kind message and a link to the carrier-profile example. Claims made in chat/issues ("feels faster") get a bot nudge to file a measured table or retract (culture enforced by tooling, not tone).

## 13. Kernel selftests & device-tree validation in CI (cheap gates, high signal)

`kselftest` subset per MR touching kernel (defconfig build job extended): `binderfs_test`, `sync_test`, `dmabuf-heap-test`, `seccomp_bpf_test`, `timers` (suspend-adjacent clocksource stability — failures here predict field suspend bugs). Full `kselftest` nightly on REF-A (results diffed vs previous night — new failures bisect-trigger per ch.03 §21 72h rule). DT validation: `dtbs_check` + `dt-validate` on every overlay MR (ch.03 §22 checklist automated) + boot-with-overlay on sacrificial unit for `status="okay"` flips (a DT change that never booted is a rumor, not a change).

## 14. batterystats methodology (Android-side power truth reconciled with host)

Collection: `dumpsys batterystats --reset` at scenario start → run scenario → `dumpsys batterystats > bs-<scenario>.txt` + `batterystats --history` slice; host side simultaneously: `halide-power top --record` CSV (ch.10 §8). Reconciliation rule (§7 stats table): top-5 consumers must agree within 20% across stacks (bigger gap = accounting bug — bridge-daemon energy unattributed is the usual suspect; attribute it, don't average it away). UID-attribution audit quarterly: every persistent top-10 UID named (mystery UIDs are wakelocks in disguise). `batterystats` reset discipline in dogfood: reset at each charge-full (comparable discharge windows — unreset stats compared across different windows is numerology).

## 15. Soak & aging tests (bugs that only appear on day 3 — scheduled, not hoped-away)

72h lab soak per release-candidate (sacrificial REF-A, SIM+Wi-Fi on, scripted daily rhythm: calls/SMS hourly, browsing bursts, camera 10 shots/day, suspend overnight): monitored metrics (unsolicited reboots 0-tolerance, `wakeup_sources` storm emergence vs day-1 baseline, `dmesg` error-counter growth, free-mem/ion-heap trend — slow leaks graphed, not eyeballed, with slope-alert threshold committed in `tests/soak-alerts.conf`), modem reattach count (0 expected — reattaches investigated per ch.07 §15 ladder, not normalized), battery gauge drift (full-charge-capacity vs day-1 ±3% or gauge re-cal issue filed). 30-day dogfood-extended aging (2 volunteers keep RC past release): monthly check-in (same form as §10 dogfood daily, weekly cadence) — long-tail leaks (month-scale) caught here; findings feed next cycle's soak-alert thresholds (thresholds learn from field, documented per change).

Flash-wear aging model (documented estimate, not guarantee): userdata write-amplification measured per RC (`/sys/block/*/stat` sectors-written over soak ÷ user-data delta = WA factor; committed per SKU) → projected life vs UFS TBW rating → published in power/results sheet footer (enterprise P3 fleet planning uses this — honest estimate with method beats silence).

## 16. Release QA sign-off (the signature page — names, not "QA approved")

Sign-off form (`qa/signoff-<ver>.md`, committed pre-rollout-past-10%): per-gate evidence links (dogfood counts + dates, CTS/VTS XML paths, power sheets, soak report, attack-subset log, lockscreen-5 record, crypto-erase + relock + rollback drill dates — each link resolves to a committed artifact, not a chat message), exceptions granted (each: what, why, compensating control, expiry — zero-exception releases state "none" explicitly), dissent recorded (any lead may file DISSENT with reason — dissent doesn't block alone but ships in release notes internally + forces Arch review; silent disagreement discovered post-release is the failure mode this prevents), signatures (QA lead + Security + Arch + Program with timestamps — same names as ch.00 gate rules). Sign-off published internally at RC, externally summarized in release notes (ch.09 §14 GATES line consumes this form — numbers flow, not retyped). Post-release 48h watch roster named in the form (who stares at rollback-rate + crash telemetry at 1%/10% stages — ch.09 §4 auto-halt has human eyes too).

## 17. Test-data management & goldens versioning (goldens rot — version the truth)

What is golden vs generated: golden = committed reference (screenshot PNG, GPX track, batterystats slice, CTS XML summary, power CSV baseline); generated = per-run output compared against the golden. Rule: no test compares against a golden that isn't versioned with the code that produces it (golden + producer pinned together in the same MR — updating one without the other fails review).

Layout (`tests/goldens/<suite>/<sku>/`): each golden dir carries `GOLDEN.json` (producer: script + args + MANIFEST.lock SHA + firmware SHAs + ambient/cell profile where relevant per §12 footnotes; tolerance: pixel %, timing ms, current mA; expiry: goldens older than 6 months or 2 releases require re-validation stamp, never silent continued use). Screenshot goldens (drawer, Phosh lock, boot splash): PNG + tolerance ≤2% pixels (§11 nightly rule) + lux/brightness record (unmatched-brightness goldens are the #1 false-red source — footnote lint §12 rejects brightness-less screenshot tables).

Golden update protocol (anti-churn): (1) producer-code change lands first with old golden marked `STALE-EXPECTED` (CI informational, not red, for ≤7 days); (2) regenerate on reference hardware (labeled unit, §7 inventory — never QEMU-regenerated goldens promoted to hardware suites); (3) human side-by-side sign (QA + area owner, diff attached to MR — auto-approve-golden MRs are banned); (4) commit golden + GOLDEN.json bump together. Unreviewed golden regeneration (`--update-goldens` run by bot without sign) is a CI fail — bots propose, humans dispose.

Retention & storage: goldens in git (small: PNG <500KB, CSV/TXT; large traces in artifact store with SHA pointer — repo-layout LFS-equivalent rule); per-release snapshot tag (`goldens-<ver>`) so release-comparison reports (§20) can diff across releases; quarantine-adjacent: flaky-golden (tolerance exceeded >5% over 50 runs, §6 flake policy) gets tolerance-review (widen tolerance with evidence + Arch sign, or fix producer — tolerance widened without evidence = test deleted with extra steps).

## 18. Lab access & scheduling policy (two REFs, ten requesters — schedule or fight)

Access tiers: Tier-0 on-call + release-blocker triage (preempts any booking ≤2h, logged); Tier-1 scheduled nightly/QEMU-adjacent hardware runs (CI-owned windows 22:00–06:00); Tier-2 engineer debug bookings (business hours, ≤4h blocks); Tier-3 community porting mentees (Friday office-hours window, ch.11 §7 — mentee access never preempted without 48h notice + reschedule offer, trust compounds).

Booking mechanics: `lab/CALENDAR.md` (or tracker equivalent) — unit label + rig (UART/PSU/RF-bag/callbox) + SIM identity (which carrier SIM stays in which unit — SIM-swap log mandatory, undocumented swaps invalidate radio results per ch.07 §18 campaign-log rule) + expected power state on return (charged ≥60%, airplane-off, SIM restored — leave-no-trace rule; violators lose Tier-2 for a week, enforced kindly, publicly). Remote access: UART-over-USB + `fastboot`/`adb` via lab runner SSH (keys in `lab/access.md`, rotated quarterly); no direct RF-chamber remote flashing without Tier-0/1 (bricked-remote-unit recovery needs hands — policy, not paranoia).

Contention rules: release week freezes Tier-2/3 on gating units (announced Monday standup ch.11 §7); soak tests (§15 72h) book whole-unit with `DO-NOT-TOUCH` tag + physical label (touching a soak unit = incident, filed as lab-infra per §11 runbook); infra-flake exit-2 during someone's booking → booking extended by lost time automatically (fairness encoded, not negotiated). Quarterly lab review (owner QA): booking utilization, preemption counts, infra-flake MTTR (§11), calibration ages (ch.11 §15 renewals) — under-30%-utilized rigs get lent to mentees, over-90% triggers procurement ask in `program/BUDGET.md`.

## 19. Metric dashboard definitions (one screen per question, no vanity graphs)

Dashboard source discipline: every panel links its query + data table + footnote set (§12 — panels without footnotes are decoration). Update cadence committed per panel (CI-push vs nightly vs weekly); stale-panel (no update past 2× cadence) shows `STALE` banner automatically (stale numbers presented as fresh is the dashboard lie this kills).

D1 Build health (owner Release): MR-merge latency p50 (target <48h), CI-green rate (target >90%), nightly-boot rate (100% required, §11 nightly), BUILD-BLOCKED hours/month (ch.09 §18 triage log). Red-action per metric named (e.g., green-rate <90% → flake-review per §11; nightly red → page infra same-day).

D2 Radio quality (owner Telephony): stall-rate per device-week (gate ≤2, §20 ch.07), attach-time p50/p95 (gate ≤90s), setup-success/drop % (gates §22 ch.07), airplane-recovery ≤60s hit-rate, modem-crash count/week (P0 at >1, ch.07 §15). Split by carrier/SKU/fw-version (fw is a dimension per ch.07 §23 — dashboards that average across fw hide regressions).

D3 Power & thermal (owner QA): standby-drain vs stock delta % per scenario (§8 gate table), suspend-residency %, top-3 `wakeup_sources` deltas, skin-temp max per scenario (§4 ≤45°C report), flash WA factor (§15). Each point links `power/<sku>/results.md` row + calibration.md offset (§8 meter-lie documented).

D4 Quality gates (owner QA): dogfood P0/P1 per 1,000 device-days (trend down), quarantine size vs cap-5 (§11), flake-rate per suite (target <5%), soak-alert slope breaches (§15), CTS/VTS allowlist pass + quarantined count (§9). Gate-readiness vote reads D4 top-to-bottom (ch.10 §16 sign-off consumes — numbers flow, not retyped).

D5 Security posture (owner Security): patch-lag days per stream (≤30 target / 60 gate, ch.08 §11), fuzz-crash MTTR + coverage trend (ch.08 §§10/17), expired-sepolicy-rule count (0), drill completion (embargo/wrong-key/wipe/lockscreen dates + pass/fail). Any red here blocks release promotion independent of D1–D4 (security veto written into the dashboard, not just §18 prose).

## 20. Release-comparison report template (every release answers: better than last?)

Generated per RC from committed artifacts (no hand-typed numbers — script `tests/release-compare.sh <prev> <curr>` emits the report skeleton; humans add verdicts, never numbers):

```
HALIDE <curr> vs <prev> — comparison (<date>, author)
BUILD: MANIFEST delta (pins changed, lines) · repro-match (Y/N) · stage-time deltas
CTS/VTS: allowlist <x/y → x'/y'> · quarantined <z → z'> · newly-green <list> · newly-red <list + bugs>
POWER: per-scenario delta table (curr vs prev vs stock): scenario | prev mA | curr mA | Δ% | verdict
RADIO: attach p50 <a → a'> · stall-rate <s → s'> · drop % <d → d'> · fw change? <Y/N + re-bless status>
PERF: boot <s → s'> · cold-start median <x → x'> · jank % <j → j'>
SOAK: 72h verdict + slope-alert deltas · aging volunteer notes (if any)
DOGFOOD: P0/P1 per 1k device-days <prev → curr> · worst-thing-today themes (top-3 quoted, anonymized)
SECURITY: CVE dispositions delta · patch-lag delta · fuzz MTTR delta
GOLDENS: changed <list + MR links> · stale-flags cleared/added
VERDICT PER AREA: <better / same / worse + one-line evidence> (Telephony, Power, Perf, Security, QA)
SHIP RECOMMENDATION: <go / hold-for <bug> / needs-extended-soak> + named dissent (ch.10 §16 rule)
```

Comparison honesty rules: same-unit comparisons only (unit labels in footnotes — cross-unit deltas are lab noise presented as product news); ambient/cell mismatches invalidate power/radio rows (marked `INVALID-RERUN`, not footnoted-away); `worse` verdicts require a filed bug linked (worse-without-bug = report rejected in review). Report committed at `qa/compare-<prev>-to-<curr>.md` before rollout passes 10% (same timing as ch.09 §14 notes — early adopters read, late majority benefits) and linked from release notes COMPAT/GATES lines.

## 21. Camera, GNSS & audio acceptance operations (Phase-3b gates made executable)

Camera (libcamera path, no stock-parity claims per ch.11 risk-2): acceptance set per SKU — 20-still burst (`camera-burst.sh` §7: EXIF present, hash-logged, green-frame histogram check 0 failures), 5-min 720p video (no frame-drop >2%, no thermal abort below §4 70%-clock rule), front/rear parity of controls (exposure/focus/white-balance converge ≤3s each, timed in script), stock-oracle delta sheet (same scene, same lux: side-by-side + subjective note "softer detalj / warmer WB" — honest delta language committed, never "comparable"). Tuning constants live in `camera/<sku>/tuning.json` (versioned with goldens §17 — tuning change without golden re-sign fails review). Failures file against camera-tuning-sheet with frame samples (redacted of people — lab test-cards only in committed samples).

GNSS (PDS/QMI path, gnss-deepdive fixture): cold-start TTFF ≤60s open-sky (3 runs median, `gnss-track.sh` NMEA), 15-min walk track vs stock GPX overlay (drift ≤15m RMS open-sky; urban-canyon runs recorded but non-gating with `URBAN` tag — gating on canyon data fails every phone ever made), airplane-toggle re-acquire ≤30s. Coexist note (wifi-bt-coexist doc): GNSS run repeated with Wi-Fi scan storm + A2DP streaming active (TTFF degradation >50% = coexist P1, not "physics"). Results in `gnss/<sku>/results.md` with footnote set (§12: unit, firmware, sky view photo, cell-on/off state).

Audio loop (modem-audio-loopback-tests + ch.04 proxy): host-only loopback first (modem PCM → mixer → earpiece, no Android — isolates gains from bridge), then bridged (Android Dialer-equivalent path where present), 5 scripted scenarios from ch.07 §4 (quiet/street/car/speaker/headset) with subjective scores + underrun counts (§22 ch.07 metrics feed). Gate: 0 one-way-audio in 50 calls (shared with ch.07 §22 — same count, one owner: Telephony; QA witnesses, both sign §16 form).

## 22. Runner-fleet maintenance & lab hygiene (the lab is infrastructure — treat it so)

Runner fleet (QEMU hosts + lab-runner PCs driving REF units): pinned OS image (`lab/runner-image.md`: Debian stable digest + packages lock, same pinning doctrine as ch.09 §7 builders — unpinned runners produce unexplainable reds), disk-space guard (nightly `df` check, alert at 80%, auto-prune artifacts past retention before any run — disk-full mid-soak invalidates 72h, the guard exists because it happened once), USB-port mapping log (which unit on which port/hub — hub-swap without log update pages the booker with a kind message + link, second offense buys the lab coffee).

Monthly hygiene (owner QA, 1h, calendar-committed): cable continuity spot-check (orientation-labeled set §7 — frayed C-C cables quarantined physically, red tape, photo in lab log), PSU calibration sticker check (age >1y → renew per §15 calendar; expired-calibration runs tagged `UNCALIBRATED`, non-gating), SIM inventory vs custody log (ch.11 §18 carrier category — missing SIM = incident, not mystery), UART-rig driver re-probe after host updates. Quarterly: full runner-image rebuild + reboot-storm test (10 reboot cycles on idle units proving the lab survives its own maintenance). Spare-parts shelf (owner QA, capped spend under ch.11 §18 lab category): 2 spare USB-C cables per connector type, 1 spare PSU lead set, 1 pre-flashed SD/USB with the runner image (unlabeled mystery media is banned from the lab — every stick carries a dated label or it lives in the bin). Loan log for off-site units (dogfood spares, mentee loans): serial + holder + expected return + flashed version on return (returned units get wiped with attestation per ch.08 §21 before re-entering the pool — no exceptions for "it was only a mentee").

## 23. Display acceptance automation (brightness-matched, or it didn't happen)

Scope split with §21 (camera/GNSS/audio ops) and §17 (goldens): this section owns the display rig + scripts + tolerances that make composer screenshot diffs (§11 nightly drawer diff ≤2% pixels) trustworthy instead of flaky. All committed display numbers carry the §12 footnote set (unit label, firmware SHAs, ambient, brightness nits, run count) — brightness-less display tables fail `perf-footnote-lint.sh` by rule.

Fixture (per lab, committed in `lab/display-rig.md` with photo): light-controlled corner or blackout hood over the unit (ambient variance is the #1 false-red — hood-or-dark-room required for golden captures, lux reading recorded per run via cheap USB lux meter); fixed mount jig (3D-printed or clamped cradle holding REF-A/B at identical distance/angle to a tripod USB camera for external captures where needed; internal `screencap` is primary, external photo is secondary for backlight-bleed/brightness-uniformity checks only); brightness jig (display set to exactly 200 nits measured with the lux meter at 30 cm, auto-brightness OFF, night-light OFF — unmatched-brightness goldens banned per §17); orientation lock matrix (portrait + landscape captures for drawer + lock + boot splash; rotation-sensor state logged per capture so a rotation-race isn't misread as a rendering bug).

Scripts (`tests/display/`): `display-sweep.sh` (sets brightness ladder 50/100/200/300 nits → `screencap` per step → records nits + PNG SHA; catches gamma/quantization cliffs where a tolerance-pass at 200 nits hides banding at 50); `composer-diff.sh` (boots to Phosh drawer → waits for `boot_completed` + 5s settle → captures → compares vs `tests/goldens/composer/<sku>/drawer.png` with ≤2% pixel tolerance per §11; emits side-by-side diff PNG + pixel-% + histogram delta on fail — fail artifacts include the diff, never just "mismatch"); `jank-measure.sh` (Perfetto `frame_timeline` 60s scroll script: scripted swipe cycle via `input swipe` at fixed velocity → missed-vsync % + p95 frame time; gate §4 <5% missed vsync, 10-run median reported); `backlight-uniformity.sh` (full-white/gray/black captures + 9-zone luminance sampling from external camera; uniformity delta >15% center-to-corner files a P2 display-calibration issue against `display-calibration-procedure.md`, non-gating unless paired with §4 thermal complaint).

Golden discipline (instantiates §17 for display): every display golden dir carries `GOLDEN.json` (producer script + args + MANIFEST.lock SHA + brightness nits + ambient lux + unit label); goldens older than 6 months or 2 releases need re-validation stamp (§17 expiry); `STALE-EXPECTED` 7-day window (§17 protocol) used for composer changes (producer lands first, golden follows with QA + area-owner side-by-side sign — auto-approve-golden MRs banned, bot rejects `--update-goldens`-without-sign per §17). Tolerance-widening requires evidence + Arch sign (widening because "the lab got brighter" is rejected — fix the hood, not the tolerance).

Stock-oracle comparisons (same doctrine as §21 camera honesty): same scene/brightness/ambient, HALIDE vs stock-reference phone (§7 inventory oracle) side-by-side committed; subjective notes use delta language ("cooler white point ~500K, bottom bezel shadow visible at 50 nits") never "comparable". Display regressions vs previous release block per §9-style diff discipline (use `tests/release-compare.sh` PERF rows §20 — display jank deltas appear there, not in chat).

Infra-flake separation (§7 exit-2 contract): hood-left-open (lux outlier >20% vs GOLDEN.json ambient) and mount-bump (external-photo alignment score <threshold) exit 2 with the cause named (`FAIL-INFRA lux=...` / `FAIL-INFRA alignment=...`), counted per §11 lab-infra MTTR, never retried into green silently; 3 same-cause infra-flakes/month = lab P1 (fix the hood/jig per §11, and the §22 monthly hygiene hour owns the action).

## 24. Camera & GNSS acceptance automation deep-dive (fixtures, tracks, coexistence)

Builds on §21 ops + §7 harness scripts; this section specifies the automation that makes `camera-burst.sh` and `gnss-track.sh` reproducible across runners and quarters. Carrier-profile footnotes (§12) apply to every committed camera/GNSS table (unit, firmware, lux/sky-view, cell-on/off, build SHAs).

Camera rig (`lab/camera-rig.md` + photo): fixed test-card wall (ISO-12233-style chart + X-Rite-class color card + low-light gray card, all labeled with purchase date — faded cards replaced annually, faded-card runs tagged `UNCALIBRATED` per §22 calibration doctrine); lux-controlled lighting (3 levels: 1000 lux daylight-equivalent, 100 lux indoor, 10 lux low-light; lux meter reading per run, auto-white-balance converges ≤3s per §21 control timing); tripod mount at 50 cm for rear, 30 cm for front (handheld runs allowed only with `HANDHELD` tag, non-gating — handheld variance invalidates golden comparison per §17 same-unit rule).

Camera automation (`tests/camera/`): `camera-burst.sh` extended (20 stills per lighting level → EXIF-present check + SHA log + green-frame histogram detector (§7) + focus-score per frame via Laplacian variance; 0 green-frames + focus-score p10 above `camera/<sku>/tuning.json` threshold = PASS; tuning constants versioned with goldens §17 — tuning change without golden re-sign fails review); `video-soak-5min.sh` (720p 5-min capture → frame-drop % via container count vs wall-clock, thermal-abort check against §4 70%-clock rule, audio-underrun count fed to §21 audio gate); `controls-timing.sh` (exposure/focus/WB converge timers per §21 ≤3s each, 5 repeats median); redaction rule (lab test-cards only in committed samples — no people per §21; any committed frame with EXIF GPS present is stripped + build fails with the file named, same redaction discipline as ch.09 §4 `halide-ota-report` redacted-only rule).

GNSS rig (`gnss/<sku>/fixtures.md`): open-sky reference point (lab roof or parking-lot marker with sky-view photo committed per quarter — sky-view changes with seasons/construction, photo dates the claim); shield-bag negative control (TTFF must *not* complete in-bag within 5 min — validates the fix in open-sky was satellite-derived, not cached/Wi-Fi-derived); walk-track course (15-min loop with stock GPX oracle per §21, same carrier/SIM state both runs — cell-on/off changes assistance data, mismatched runs marked `INVALID-RERUN` per §20 honesty rules).

GNSS automation (`tests/gnss/`): `gnss-track.sh` (cold-start TTFF 3-run median ≤60s open-sky §21 → NMEA log + TTFF CSV; 15-min walk NMEA → RMS drift vs stock GPX ≤15m open-sky, urban-canyon tagged `URBAN` non-gating; airplane-toggle re-acquire ≤30s); coexist sweep (wifi-bt-coexist doc scenario: repeat TTFF with Wi-Fi scan storm + A2DP streaming active; degradation >50% = coexist P1 per §21); assistance-state logging (Almanac/Ephemeris age + SUPL on/off per run — assistance-mismatched comparisons rejected by review, same-unit + same-assist rule from §20 comparison honesty). Results committed to `gnss/<sku>/results.md` with footnote set; `tests/release-compare.sh` carries GNSS rows (§20 RADIO-adjacent — GNSS worsening without a filed bug rejects the report per §20 `worse-without-bug` rule).

Ownership & cadence: camera/GNSS suites run nightly on REF-A (§11 nightly) + full matrix per RC (both REFs × 3 lux levels × open-sky/canyon tags); failures file with frame/NMEA samples + footnote block (sample-less camera bugs bounce with a kind link to this section); quarterly fixture review in the §22 monthly-hygiene hour (card fade, sky-view photo refresh, tripod tightness, lux-meter calibration sticker — expired-calibration runs non-gating per §22).

## 25. Long-tail bug archaeology process (bugs that only appear on day 3 get a dig site)

Purpose: soak failures (§15 72h), month-scale aging leaks, intermittent radio stalls (ch.07 §15 ladder), and flaky-golden tolerance breaches (§17) share one property — the failing state is gone by the time a human looks. This section makes post-mortem evidence survive long enough to be exhumed. All archaeology artifacts are redacted by default (redacted logs only — ch.09 §4 report rules + §10 log-pipeline consent; raw bundles never committed, quarantine-store only with expiry).

Preservation triggers (any one freezes evidence automatically): soak slope-alert breach (`tests/soak-alerts.conf` thresholds §15); unsolicited reboot on soak/dogfood unit (ramoops + tombstone + `batterystats` slice per §10 log pipeline); modem reattach or data-stall requiring manual recovery (ch.07 §§15/22 counts); quarantine-nominated flake with <20% reproduce rate (§11 — low-rate flakes need the longest evidence tail); rollback-rate spike on §20 dashboard (ch.09 §§20/26 autopilot log line linked). Freeze action (`tests/freeze-evidence.sh <trigger-id>`): snapshots `dmesg` + `wakeup_sources` history + `halide-power top --record` tail + NMEA/modem slice where relevant + MANIFEST.lock SHA + firmware SHAs + unit label into `qa/digs/<date>-<trigger>/` with 90-day retention (soak/dogfood evidence outlives the 30-day quarantine expiry §6 so re-nominations can compare across windows).

Dig format (`qa/digs/<id>/DIG.md`, one page, same template every time): symptom (one line + first-seen build/date), evidence pointers (frozen paths + SHAs, never pasted dumps), timeline (build → soak-day → trigger-time with UTC stamps), hypotheses ranked (≤3, each with disproving test — hypothesis-without-test is storytelling), bisect status (MANIFEST delta range + `repro-stage.sh` equivalent for tests: `tests/repro-flake.sh <suite> <seed>` recorded command per ch.09 §18 isolate discipline), verdict (`NEW-BUG <id>` / `DUPE <id>` / `LAB-INFRA <id>` / `NEEDS-LONGER-SOAK` with extended-soak booking per §18 contention rules). Digs reviewed in the weekly bug-review with Arch (§10 30-min agenda gains a fixed 10-min archaeology slot during RC weeks — long-tail items never starve behind new P0s).

Bisect & confirm discipline: MANIFEST-delta bisect for build-correlated tails (AOSP rev / kernel fragment / overlay list from ch.09 §18 log header — the header exists so bisection starts in minutes); soak-parameter bisect for time-correlated tails (halve the soak rhythm: hourly→2-hourly calls/SMS per §15 scripted rhythm; slope-alert moves with the parameter = workload-triggered, stays = clock-triggered); fix confirmation requires a 50-green streak (§11 de-quarantine rule reused) *plus* a 72h clean soak on the fixing RC for soak-originated bugs (unit-test green without soak-clean is insufficient evidence for a day-3 bug — stated here so release-day pressure can't waive it).

Learning loop (thresholds learn from field per §15): every closed dig updates either `tests/soak-alerts.conf` (slope thresholds), `tests/quarantine.txt` annotations (flake signatures), `power/<sku>/results.md` footnotes (new confound discovered), or `qa/compare-*` methodology (§20 — comparison-invalidating confounds like assistance-state or brightness mismatch get named there). Digs that update nothing are rejected in review (a dig without a prevention item repeats per ch.09 §18 close-out doctrine). Quarterly archaeology review (owner QA, 1h): dig count, median time-to-verdict, repeater rate (same-signature triggers within 90 days = prevention failed, P1 process bug), oldest open dig (age >60 days escalates to Arch with help-or-descope per ch.09 §21 clock-overrun doctrine).

## 26. Test-coverage mapping to DoD rows (every promise has a test, every test has a promise)

Source of truth: ch.01 Definition of Done rows + ch.02 §6 envelopes + ch.07 §§22–23 radio gates + ch.08 §11 patch policy + ch.09 §§2/4/11 release gates. This section maps each DoD row to executable suites so gate-readiness votes (D4 §19, sign-off §16) read coverage, not confidence. Mapping table lives at `qa/coverage-map.csv` (columns: `dod_id,area,gate,suite,script,gating(Y/N),evidence_path,owner`) and is CI-checked (see below) — prose claims without a row here don't count toward ship readiness.

Map excerpts (normative subset; full CSV governs): DoD-standby (2× stock, ch.02 §6) → `power-nightly` (`suspend-stress.sh` + `halide-power top --record 8h` §8, gating, evidence `power/<sku>/results.md`); DoD-boot (≤45s cold §4) → `boot-timing.sh` (§7 CSV columns, gating); DoD-jank (<5% missed vsync §4) → `jank-measure.sh` (§23, gating); DoD-radio (attach ≤90s, setup/drop gates ch.07 §22, stall ≤2/device-week ch.07 §20) → `call-loop.sh` + `sms-loop.sh` + `data-soak.sh` + `airplane-recovery` slice (§7, gating, Telephony owner, QA witness per §21 audio-gate shared count); DoD-OTA (A/B with health gates, rollback-on-bad demonstrated §7 `ota-rollback-test.sh`, staged 1/10/50/100% per ch.09 §§4/26 autopilot) → `ota-rollback-test.sh` + autopilot log review (gating, evidence ch.09 `release/rollout-<ver>.md`); DoD-signing (testkey-never-ships ch.09 §3) → CI `testkey-grep` + manual `avbtool info` attach (gating, blocks release unconditionally); DoD-repro (two-builder hash match ch.09 §2) → release two-builder job (gating); DoD-dogfood (7-day, 10 testers, P0/P1 taxonomy §10) → dogfood op + sign-off form §16 (gating, re-run on 2×P0-or-5×P1 rule); DoD-logs (redacted only) → upload-job PII grep + `--redact` contract audits (§7 scripts, gating — redaction failure fails the suite, not just the upload).

CI enforcement (`scripts/coverage-lint.sh`, per-MR + nightly): every `tests/*.sh` declares its `dod_id` in a header comment (`# DOD: DoD-standby,DoD-boot`); lint fails on (a) suite without a `dod_id`, (b) `dod_id` without a CSV row, (c) CSV row whose `evidence_path` has no artifact from the last nightly/RC (stale-evidence rows flagged `STALE` like §19 dashboards — stale coverage presented as fresh is the coverage lie this kills); allowlist/watchlist discipline (§9) mirrored here (watchlist suites map to informational rows, never gating — promoting a watchlist row to gating requires QA + Arch sign + 50-green streak per §11). Quarantine interaction (§§6/11): quarantined tests keep their CSV rows but flip `gating` to `N` with `quarantine-<bug>-<expiry>` annotation (quarantine is visible in coverage, never silent; cap-5 §11 enforced by lint — 6th concurrent flip fails with the fix-or-delete-an-existing-one message).

Release-consumption rule: ch.10 §16 sign-off form's per-gate evidence links *are* the CSV `evidence_path` values for the shipping RC (sign-off doesn't retype numbers per §16 — it resolves CSV pointers); `tests/release-compare.sh` output (§20) diffs coverage deltas (newly-green/newly-red/quarantined-flake counts flow from the CSV flip history, not hand-typed). Coverage gaps found pre-release file as gate-blockers with the missing `dod_id` named (gap-without-owner bounces — every DoD row has an owner column, unowned rows page QA lead within 24h per §11 triage SLA).

Quarterly map review (owner QA + Arch, 45 min): orphan suites (no DoD row — adopt, map, or delete with replacement per §6 no-delete-without-replacement); orphan DoD rows (no suite — schedule automation or downgrade the DoD with an ADR, never leave a promise untested silently); watchlist-to-allowlist promotions (IMS/DRM/biometric informational rows graduate only with fixture + golden + owner committed — graduation without a rig is how gating suites become flake farms).

## 27. Lab disaster recovery (fire / flood / theft continuity — the lab can burn, the project may not)

Threat scope (this section only): loss of the physical lab (fire/flood), loss of units (theft/seizure/shipping loss), loss of lab data (runner disk death, PSU-logger SD rot), loss of key humans (on-call unreachable during incident). Not in scope: builder-compromise (ch.09 §13), shipped-image compromise (ch.08 §8 advisory path), carrier-blessing loss (carrier-lab-handbook blessing-campaign reschedule — referenced, not duplicated). RTO/RPO: lab-bookable again ≤5 business days; no committed evidence older than 7 days lost (RPO 7d); gating RCs re-verifiable from committed artifacts + transparency (ch.09 §17) without the original bench.

3-2-1 evidence rule (audited quarterly in the §22 hygiene hour): 3 copies of gating artifacts (lab runner + artifact store + transparency-adjacent release dirs per ch.09 §17 / `cts-results/<date>/` §9 / `power/<sku>/results.md` §8 / `qa/signoff-<ver>.md` §16), 2 different media/hosts (runner disk + offsite artifact store — same-rack "backup" doesn't count), 1 offsite (nightly `lab-backup.sh` rsync of `lab/`, `power/`, `gnss/`, `qa/digs/`, `cts-results/`, `tests/goldens/` deltas + inventory CSVs; backup manifest SHA logged; restore drilled semi-annually by rebuilding `power/<sku>/results.md` + one `cts-results/<date>/` summary from backup alone — drill failure = lab P1 per §11). Redaction survives backup (backups carry redacted committed artifacts + sealed raw-quarantine with 90-day expiry per §25 — raw PII never gains a longer life via backup; quarantine expiry deletes across copies by job, logged).

Unit-loss continuity: serial-level inventory (`lab/INVENTORY.md`: unit label, serial, SKU, REF-A/B role, SIM custody per §18 + carrier-lab-handbook fleet rules, firmware last-flashed, calibration offsets §8) synced offsite with the backup (inventory loss invalidates radio/power footnotes per §12 — inventory restore is step 1 of any recovery); theft/seizure response (report + carrier SIM suspend within 24h via carrier contact log, remote-wipe where enrolled, transparency note if a pre-release-signed build was on the unit — testkey-never-ships limits blast radius: stolen dogfood units carry release-candidate or release builds whose keys are public-verifiable per ch.09 §17, never signer private keys which live offline per ch.09 §§3/15); EDL/unbrick packages per ch.09 §10 `hw/<sku>/edl.md` stored offsite (signed loader hashes in transparency — a lab fire must not strand the fleet without unbrick); spare-unit floor (≥1 spare REF-A flashable from `factory/flash-station/` ch.09 §16 + traveler template — recovery without a bootable spare isn't recovery); loan-log reconciliation on return (`wipe with attestation` per §22/ch.08 §21 before re-pooling — disaster-loaned units re-enter through the same gate, no "emergency exception").

Bench-loss continuity (no single bench is load-bearing): runner-image rebuild from definition ≤30 min per §23-adjacent ch.10 §22 doctrine (runner definitions + `lab/runner-image.md` live in git + offsite backup — bench rebuild never depends on the dead bench's disk); PSU/meter/thermal-camera calibration records in `lab/calibration/` (sticker photos + dates; §22 expired-calibration `UNCALIBRATED` tagging lets testing resume on borrowed gear with honest labels while renewals process); RF-shield bag + callbox/SIM-pair contacts in the carrier contact log (blessing-campaign reschedule within 1 week of bench recovery — carrier-lab-handbook owns the call list, this section owns the RTO clock); alternate-bench agreements (1 named fallback location — maintainer garage, university bench, or mentee Friday-window host per §18 Tier-3 — with SSH-access recipe from `lab/access.md` quarterly-rotated keys; fallback bench validated annually by running `boot-timing.sh` + `suspend-stress.sh` smoke there and committing the footnote'd table as the drill artifact).

Tabletop & fire-drill (annual, 1h, owner QA + Release + Security): scenario rotation (fire destroys bench + 1 REF-A; flood takes PSU/logger + paper travelers; theft takes 2 dogfood units + 1 runner laptop); exercise outputs (inventory-from-backup restore time, backup-manifest SHA match Y/N, transparency-dir completeness for last RC per ch.09 §17 checklist, carrier-SIM-suspend latency, spare-unit flash time vs ch.09 §10 ≤12-min budget, first post-recovery gating run green date). Findings become lab-infra issues (§11 MTTR-tracked) + one prevention item per ch.09 §18 close-out doctrine (a drill that updates nothing is theater — the DIG template §25 verdict taxonomy applies to drill findings too).

Human-continuity (bus-factor ≥2 per role): lab owner + backup named in `program/CALENDAR.md` (ch.11 §15 roster — missing-roster bot rule from ch.09 §18 applies); safe-combination/envelope locations for LUKS/offline-signer-adjacent lab secrets follow ch.08 §8 custodian model (no single-human recovery path); 48h-watch roster pattern (§16) reused for recovery shifts (named humans + handoff notes, not heroics).

## 28. Thermal soak acceptance thresholds (skin-temp limits, throttling curves, soak-gated)

Soak heat is a release gate, not a comfort note: a unit that passes 30-min video in a 23°C lab but hard-throttles to 50% clocks or burns the hand at 47°C fails Phase-3 thermal acceptance (§4 rule made measurable here). All runs use the §7 lab inventory (thermal camera shared OK, USB-PD meter logging, airplane-baseline subtracted per §8), the §12 footnote set (unit label, firmware SHAs, ambient 23±2°C, brightness 200 nits, run count), and the §22 calibration discipline (expired-calibration runs tagged `UNCALIBRATED`, non-gating). Soak rhythm: 30-min video-over-LTE (720p local file + active LTE data keepalive so modem heat counts) followed by 10-min camera burst (§8 worst-case) followed by 15-min cooldown with screen-off LTE idle, 3 runs per SKU on the labeled gating unit plus 1 run on the second unit for cross-unit sanity (cross-unit delta >3°C at the same probe point invalidates the rig, marked `INVALID-RERUN` per §20 honesty rules, not averaged away).

| Scenario (gating unless noted) | Skin-temp limit (max, thermal-camera spot) | SoC/battery probe limits | Throttling curve (PASS band) | Fail triggers P0/P1 |
|---|---|---|---|---|
| 30-min video + LTE (§4) | ≤45°C palm-side center, ≤43°C top-edge | SoC junction ≤85°C, battery ≤40°C | ≥70% sustained clocks through min 25; transient dips to 60% ≤60s allowed ×2 max | hard-throttle <70% before min 20 = P0; skin >45°C = P0; battery >40°C = P1 + battery-health-aging-policy review |
| 10-min camera burst (§8) | ≤45°C camera-ring zone, ≤44°C palm-side | SoC ≤88°C short-peak, battery ≤40°C | ≥70% clocks averaged over burst; single dip to 55% ≤30s allowed | thermal abort of capture = P0; skin >45°C sustained >2 min = P0 |
| 30-min voice call (earpiece, §8) | ≤41°C earpiece zone, ≤40°C palm-side | SoC ≤75°C, battery ≤38°C | no visible throttle (≥85% clocks); freq drop with call-audio underrun = product race (§11) | earpiece >41°C = P1; any thermal shutdown = P0 (§10 taxonomy) |
| 30-min hotspot (1 client, 100MB, §8) | ≤44°C palm-side (table-surface note recorded) | SoC ≤85°C, battery ≤40°C | ≥70% clocks; modem DRX histogram must not collapse to full-active >80% (§8 metric) | skin >44°C + DRX collapse = P1, two repeats = P0 |
| Cooldown 15-min screen-off LTE idle | back under 35°C palm-side by min 10 | SoC drop ≥15°C in 10 min | clocks return to ≥90% idle-opp within 5 min | still >35°C at min 15 = P1 (heat-trap: case, TIM, or runaway wakelock — `halide-power top --record` tail frozen per §25) |
| Urban-canyon repeat (informational, `URBAN` tag) | report-only, no gate | report-only | report-only | degradation >50% vs open-lab run files coexist P1 (wifi-bt-coexist path, same as §21 GNSS rule) |

Verification:

- [ ] 30-min video + LTE soak passes on the gating unit (3/3 runs: skin ≤45°C, clocks ≥70% through min 25, thermal-camera CSV + `halide-power top --record` tail committed with §12 footnotes).
- [ ] Camera-burst 10-min soak shows zero thermal aborts with focus-score p10 above `camera/<sku>/tuning.json` threshold and skin ≤45°C sustained rule met.
- [ ] Cooldown gate met (palm-side <35°C by min 10 of idle) on all gating runs, else heat-trap dig opened per §25 (`qa/digs/` with frozen `wakeup_sources` + power tail).
- [ ] Cross-unit sanity run within 3°C at matched probe points; larger deltas filed as `INVALID-RERUN` with rig photos, never merged into the pass average.
- [ ] Soak-thermal rows appear in `power/<sku>/results.md` and the §20 release-comparison PERF/SOAK rows before rollout passes 10% (missing rows block sign-off §16 like any absent evidence_path per §26 coverage map).

## Verification

- [ ] Allowlist CTS/VTS green on REF-A; results published.
- [ ] Power table vs stock archived; dogfood 7-day pass signed by QA lead.
- [ ] Rollback-on-bad-OTA demonstrated on hardware (forced bad slot).
- [ ] `halide-power top` triaged ≥1 real power bug pre-gate.
- [ ] Flake rate <5% over trailing 50 runs per suite (else P1 filed).
- [ ] Goldens versioned with producers; no STALE golden past 7 days without sign-off.
- [ ] Lab calendar shows zero undocumented SIM swaps in release week.
- [ ] Release-comparison report filed pre-10%.
- [ ] All 5 dashboards fresh (no STALE banner) at sign-off; release-comparison report filed pre-10%.
- [ ] Monthly lab-hygiene hour logged; calibration stickers current; loan log reconciled.
- [ ] Spare-parts shelf stocked; returned loan units wiped with attestation.

Next: `11-roadmap-risks-appendices.md`.
