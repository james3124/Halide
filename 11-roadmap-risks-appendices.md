# 11 — Roadmap, RACI, Risk Register, Licenses & Glossary
**Budget: 40,000 chars · Owner: Program · Updated every release**

## 1. Milestones (36-week v1, 4-person core + community)

| Phase | Weeks | Exit gate |
|-------|-------|-----------|
| 0 Scaffolding | 1–2 | manifests+CI+blob inventory+UART logs |
| 1 Boot-to-shell | 3–8 | systemd login + container boot_completed headless, 50 suspend cycles |
| 2 GUI+1 app | 9–16 | Phosh + Android app touch, <100ms, survives resume |
| 3a Telephony/data | 17–24 | calls/SMS/data/Wi-Fi/BT per DoD on REF-A |
| 3b Camera/GNSS/power | 25–30 | stills/video/GNSS/24h standby within envelope |
| 3c Hardening+OTA | 31–34 | AVB green, encryption, A/B rollback demo |
| 3d Dogfood+release | 35–36+ | 7-day dogfood pass, repro build, publish |

REF-B trails REF-A by ~6 weeks. VIRT/CI runs from week 2.

## 2. RACI (core)

| Area | R | A | C | I |
|------|---|---|---|---|
| Kernel/boot | BSP lead | Arch | Community ports | QA |
| AOSP/HALs | Android lead | Arch | BSP | QA |
| Debian/bridges | Platform lead | Arch | Security | QA |
| Graphics | Graphics | Platform | Android | QA |
| Telephony | Telephony | Platform | Carriers (info) | QA |
| Security/keys | Security | Arch | All | Users (advisory) |
| Release/OTA | Release | Arch | Security | Enterprise |

## 3. Risk register (top 8, triggers + mitigations)

1. **VoLTE/IMS never on some carriers** (P:high, I:high). Trigger: week 20 no IMS registration. Mitigation: blessed-carrier list + CSFB docs + data-first messaging.
2. **Camera ISP closed** (P:high, I:med). Mitigation: libcamera + documented quality delta; no stock-parity claims.
3. **Power >2× stock** (P:med, I:high). Trigger: Phase-3a standby miss. Mitigation: wakelock sprint + modem DRX tuning + feature flags (AOD off, bg-scan throttled).
4. **Single maintainer bottleneck** (P:med, I:high). Mitigation: porting guide + RACI backup per area + paid lab time budgeted.
5. **Key compromise** (P:low, I:critical). Mitigation: offline signer, dual-sign rotation, revocation OTA template ready.
6. **Legal/blob takedown** (P:low, I:med). Mitigation: extractor scripts, no forbidden redistribution, snapshot SBOM.
7. **Scope creep (GApps/Widevine L1 demands)** (P:high, I:med). Mitigation: published non-goals + issue template auto-close with link.
8. **Hardware availability** (P:med, I:med). Mitigation: 2 units per ref + emulator CI so work continues.

## 4. Licensing & attribution

Kernel GPL-2.0 sources + scripts same-day per release. AOSP Apache-2.0 notices preserved. Debian DFSG manifest. Per-image `SBOM.spdx.json` + `THIRD-PARTY` + `NOTICE`. No proprietary Google apps shipped. Trademark: "HALIDE" cleared; device codenames avoid vendor marks in marketing.

## 5. Glossary (abridged)

GKI/AVB/DTBO/A-B/QRTR/QMI/RIL/IMS/CSFB/DRM-KMS/dmabuf/SELinux/AppArmor/pKVM/LXC/binderfs/ashmem/Perfetto/mmcli/NM/MM/PipeWire/Phosh/phoc/SBOM/CTS/VTS/GTS.

## 7. Staffing & weekly cadence (36-week v1)

Core 4: BSP/Kernel lead (kernel+DT+modem-host), Android lead (AOSP+HALs+container), Platform lead (Debian+bridges+composer+Phosh), QA/Release (lab+harness+OTA+security-ops). Arch role rotates quarterly among leads (no ivory tower — Arch ships code in their home area). Community: 1 porting mentee per REF (P4 persona) from week 6, office-hours Fridays.

Weekly: Mon standup (15 min, blockers only) → Wed deep-dive (60 min, one chapter area, demo required — slides without demo don't count) → Fri office-hours + bug-review (30 min, ch.10 pipeline). Monthly: release-train review (bake metrics, quarantine expiries, TECH-DEBT ledger deltas — out-of-tree lines must not grow). Phase-gate weeks are demo weeks (hardware on camera, logs committed, gate checklist signed — no verbal gates).

Budget reality box: lab hardware (~$3–6K one-time: units+cables+meters+thermal), carrier SIMs ($50–150/mo), signing HSM/USB ($200–2K), CI runners (2× ARM64 builders or cloud equivalent). Record actuals in `program/BUDGET.md` — overruns discussed at monthly, not discovered at release.

## 8. Porting guide outline (P4 acceptance: Phase 1 in ≤4 weeks)

New-SKU onboarding (companion doc `porting/NEW-SKU.md`, written by week 10 from REF-A lessons): (1) stock GPT backup + blob inventory (ch.02 §4–5 ritual), (2) DT overlay from stock dump (`scripts/dump-stock-dt.sh` + provenance comments rule), (3) defconfig fragment (start from halide-base + SKU deltas only), (4) UART-first boot (no display needed week 1), (5) panel+touch week 2, (6) modem-host week 3 (`qrtr-lookup`→`qmicli`→MM), (7) container boot_completed week 4. Each step has a "stuck longer than 3 days?" escalation (office-hours + what logs to bring). Port accepted as community-supported when steps 1–7 logs are committed + 50-cycle suspend passes; blessed status requires full Phase-3 DoD (no shortcuts — blessed means daily-driver).

## 9. Full glossary

**A/B slots** — dual partitions enabling fallback. **ABL** — Android Bootloader (fastboot provider). **AVB** — Android Verified Boot (vbmeta chain). **CSFB** — circuit-switched fallback (LTE→3G/2G for voice). **DRM/KMS** — kernel display framework (not digital-rights). **DT/DTB/DTBO** — device tree source/binary/overlay. **DRX** — modem discontinuous reception (idle power). **EDL** — emergency download mode (last-resort flash). **GKI** — Generic Kernel Image (Google baseline). **HIDL/AIDL** — HAL interface languages. **LXC** — Linux containers (Android runtime home). **MM/NM** — ModemManager/NetworkManager (host truth). **PDS** — position determination service (GNSS over QMI). **QRTR/QMI** — modem control fabric/protocol. **RIL/IRadio** — radio interface layer. **SPL** — Android security patch level. **SBOM** — software bill of materials. **STK** — SIM toolkit. **TEE/QSEE** — trusted execution (out of v1 scope except SW keymaster). **VTS/CTS/GTS** — vendor/compat test suites. **XTS/Argon2id** — disk-encryption cipher/KDF.

## 10. License & trademark operations

`scripts/license-check.sh` per release: kernel `COPYING` + per-file SPDX present, AOSP `NOTICE`完整, Debian copyright aggregation, firmware redistribution flags re-verified (a blob that was extract-only last release is re-checked — licenses change). `THIRD-PARTY` generated from SBOM (name+version+license+URL per component; unknown-license = block). Trademark: HALIDE wordmark cleared via search (record date/counsel-or-self); no vendor marks in image names (`halide-sdm845` not `halide-oneplus`); codenames are internal (`REF-A`) until blessed with neutral public name.

## 11. Program metrics (reviewed monthly — trends, not snapshots)

Build health: MR-merge latency median (target <48h — slow reviews kill momentum silently), CI-green rate (target >90% — below means flaky gates, ch.10 §11), nightly-boot rate (100% required — red nightly pages infra same-day). Quality: gate pass/first-try rate per phase (trending up = process learning), dogfood P0/P1 per 1,000 device-days (trending down), quarantine size vs cap-5 (ch.10 §11), out-of-tree kernel lines (strictly decreasing per ch.03 §20 — graphed). Security: patch-lag days per stream (≤30 target, 60 gate), fuzz-crash MTTR, expired-sepolicy-rule count (0). Community: porting mentee week-1 success (ch.11 §8 acceptance), fresh-eyes drill completion (annual), support-script SLA hits (ch.10-adjacent support doc). Every metric has an owner + a "what we do when red" line (metrics without responses are wallpaper).

## 12. Quarterly objectives discipline (OKR-lite — objectives fit on one page)

One product objective (e.g., "REF-A reaches Phase-2 gate"), one quality objective (e.g., "flake rate <5% all suites"), one upstream objective (e.g., "10 out-of-tree patches upstreamed") per quarter — three total, not nine. Scored 0.0–1.0 at quarter end in `program/Q<Y>-<N>-review.md` (0.7 = good — 1.0s mean targets were timid). Missed Phase-gate quarters trigger the Arch review from appendix-02B §2 pattern (extend-once / demote / drop — same discipline inward). Objectives set with the team present (dictated OKRs are fiction with numbers).

## 13. Extended risk register (risks 9–14 — the second-layer risks that kill year two)

9. **AOSP major-version rebase stalls hybrid** (P:med, I:high). Trigger: bump branch older than 2 bulletins (ch.04 §18 step-1 age check). Mitigation: monthly rebase-cadence even without features (small diffs compound less), netd-table triage budgeted 3 days/bump, owner Android-lead, review date quarterly.
10. **Carrier firmware update breaks third-party IMS/CSFB** (P:med, I:high). Trigger: blessed-carrier regression in nightly radio smoke. Mitigation: carrier-matrix re-test on modem-fw change (fw version is a matrix dimension, ch.07 §11), fallback label updated within a week (no stale VERIFIED), owner Telephony, review per modem-fw release.
11. ** Dogfood fleet bias (all-hacker fleet misses normie bugs)** (P:high, I:med). Trigger: P1-heavy release with zero dogfood P1s (fleet didn't represent users). Mitigation: fleet quota — ≥4 non-hacker testers (ch.10 §10 fleet mix enforced at recruitment, not wished), support-script pain-sync (support-log-script §3) as second sensor, owner QA, review per dogfood.
12. **Key-custodian unavailability blocks release** (P:low, I:high). Trigger: ceremony delayed >2 weeks for attendance. Mitigation: 3 custodians cross-trained (any-2 quorum, ch.08 §8 ceremony updated), drill includes stand-in pair annually, owner Security, review semi-annually.
13. **Upstream kernel LTS EOL forces major jump mid-program** (P:med, I:med). Trigger: selected LTS announces EOL <12 months out. Mitigation: LTS selection requires ≥3y remaining at program start (record EOL date in MANIFEST.kernel adjacent file), jump planned a quarter ahead with bisect capacity reserved (ch.03 §21), owner BSP, review annually.
14. **Scope re-entry via "just this one GApp"** (P:high, I:med). Trigger: any MR/issue proposing bundled proprietary app. Mitigation: ch.01 §4 non-goals + §12 services position cited in close-template (auto-reply text committed, not improvised), owner Arch, review per occurrence (count tracked — rising count means messaging failed, fix messaging).

## 14. Decision log (ADRs — the why behind the what, newest first)

Format per entry (`program/adr/<NNN>-<slug>.md`): Context → Options (≥2 with tradeoffs) → Decision → Consequences (what gets harder) → Revisit-when (date or trigger — decisions without revisit conditions calcify). Seeded entries: ADR-001 systemd-as-PID1 over Android-init (ch.00 decision + ch.05 consequences: RIL/audio bridging cost accepted); ADR-002 single-stack NM networking (ch.05 §4/bridges-netd — Android second-supplicant forbidden); ADR-003 host-owns-modem (ch.07 §1 — dual-master ban); ADR-004 no-GMS v1 (ch.01 §12 — trust posture); ADR-005 erofs read-only partitions (ch.09 §8 — verity + repro); ADR-006 permission atomicity (bridges/permission §2 — no split-brain). New architecturally-significant choice without ADR = review fail (repo-layout §3 merge rules reference this — the question "where's the ADR?" asked in review, kindly, every time).

## 15. Program calendar (the year at a glance — recurring events with owners, not hopes)

Weekly: Mon standup / Wed demo-deep-dive / Fri office-hours + bug-review (ch.11 §7). Monthly: release-train review (bake metrics + quarantine expiries + TECH-DEBT delta + metrics review §11). Quarterly: gate-readiness (phase gates ch.00), lockscreen-bypass session (attack-test §5), embargo/wrong-key drills (08 §§8/13), review-retro calibration (review-sla §3), fresh-eyes port or flash drill (ch.09 §10 / ch.01 P4). Semi-annually: compat-list refresh (01 §15 quotas), TTFF/coexist re-validation (gnss §2–3), support-script wording test (support-log-script verification). Annually: pentest (08 §18 scope), GPL-packet rebuild drill (sbom §4), EOL-policy review (eol §1 dates still sane), calibration renewals (02 §13), tabletop live-fire week (08 §12). Calendar lives in `program/CALENDAR.md` with automatic issue-filing (missing recurring event = bot files it — discipline automated, not remembered).

## 16. Post-v1 roadmap (sequenced, not promised — order is the plan, dates are forecasts)

Phase-4 candidates in priority order (re-vote at v1 ship with dogfood + support-pain data — order changes only with evidence): (1) dual-SIM active (ch.07 §17 sketch → plan; gated on hardware-RF proof), (2) eSIM/LPA (ch.07 §19 undecided-list → decisions), (3) NPU enablement (ch.04 §20 triple-condition), (4) HDR pipeline (ch.06 §13 sketch → code behind panel measurements), (5) split-screen Android+Linux (ch.06 §4 stretch → design), (6) second form-factor evaluation (tablet-class — only after phone DoD holds 2 releases; form-factor creep killed more mobile projects than modems). Non-roadmap (rejected with reason logged, not silently queued): GMS bundling (ch.01 §12 posture stands until a lawful+trust-preserving path exists — bar named, not moved), Widevine L1 (needs TEE program — tracked as dependency, not task), pKVM split (ch.00 rejected-approach stands until modem/GPU passthrough matures — revisit trigger named). Forecast horizons: next-quarter committed (funded + owner), half-year shaped (sketches exist), year+ directional (one paragraph each — detail without commitment is fiction).

## 17. Hiring & ramp plan per phase (4 core → N without losing the plot)

Staffing envelope (binding assumption for all dates in §1): v1 ships with 4-person core (§7 roles). Growth is phased, not front-loaded — hires land ahead of the phase that needs them, with a named buddy and a 4-week ramp definition of done.

| Phase | Hire (role, FTE) | Why now | Ramp DoD (week 4) | Buddy |
|-------|------------------|---------|-------------------|-------|
| 0–1 | 0 hires; 2 porting mentees (P4, volunteer, from week 6) | core validates bring-up before teaching it | mentee completes §8 steps 1–4 on REF with logs committed | BSP lead |
| 2 | +1 Graphics/composer contractor (0.5 FTE, weeks 9–16) | Phosh+composer+drawer is the critical path | 1 jank bug triaged with Perfetto + 1 screenshot-diff green | Platform lead |
| 3a | +1 Telephony/carrier engineer (1.0 FTE, weeks 17–24) | carrier matrix + stall/voice baselines need a full-time owner | 1 carrier blessed solo (campaign log §18 ch.07) | Telephony (or Platform pre-hire) |
| 3b–3c | +1 QA/lab technician (1.0 FTE, weeks 25–34) | power lab + soak + factory station need hands, not heroes | runs factory flash ≤12 min + files 1 power sheet solo | QA/Release |
| 3d+ | +1 Security-reviewer (0.5 FTE retainer, weeks 31+) | ceremony + embargo + pentest scope need a second pair of eyes | co-signs 1 ceremony + triages 1 bulletin batch | Security |
| Phase-4 | +1 modem-fw/vendor liaison (TBD, gated on dual-SIM/eSIM vote §16) | vendor escalation is a skill, not a side quest | owns 1 fw re-bless cycle (ch.07 §23) | Telephony |

Ramp kit (same for every hire, week 1): onboarding checklist (`onboarding-checklist.md` — UART log captured, redacted bundle produced, 1 MR merged with gate evidence, support-log-script role-play passed). No hire merges to release train before ramp DoD (develop-only MRs weeks 1–4 — the train is not a classroom). Backfill rule (ch.11 risk-4 mitigation made concrete): every area has a named backup in RACI §2 who has merged ≥1 MR in that area in the trailing quarter — backup without recent commits is a name on a slide. Hiring freeze trigger: MR-merge latency p50 >72h (§11 metrics) = no new scope until review latency recovers (adding people to a clogged review pipeline pours water into a blocked drain).

## 18. Budget tracking categories (actuals in `program/BUDGET.md`, reviewed monthly)

Categories (each with owner, quarterly cap, and overrun rule — overrun without a logged decision at monthly review = process fail, not "agile"):

1. Lab hardware (owner QA; cap set per §7 box $3–6K one-time + $1K/y refresh): units, cables, PSU/meters, thermal camera, RF-bag, UART rigs. Asset log (`program/ASSETS.md`: unit label, serial, purchase date, holder — unlogged hardware walks away; annual inventory at EOL-policy review §15).
2. Carrier & connectivity (owner Telephony; $50–150/mo): SIMs per blessed carrier, top-ups for soak/data campaigns, callbox time-share where applicable. SIM custody log (which SIM in which unit — feeds ch.07 §18 campaign validity + ch.10 §18 booking rule).
3. Signing & trust (owner Security; $200–2K one-time + $200/y media rotation): HSM/USB signer (§19 ch.08), sealed off-site media, tamper tape/envelopes, ceremony travel if custodians remote. No spend here is deferrable past ceremony-due dates (ch.08 §8 quorum + ch.11 risk-12 — saving $200 by skipping backup media is the most expensive saving available).
4. CI & builders (owner Release; metered monthly): ARM64 builders (owned vs cloud — decision + cost comparison committed annually; flip only with repro-parity proof ch.09 §2), artifact retention overage past 180 days (§11 ch.09 — retention growth is a cost line, graphed), mirror audit bandwidth (ch.09 §19 weekly fetches).
5. Security review (owner Security; annual): pentest (ch.08 §18 scope — fixed-fee with finding-SLA terms, not open-ended), researcher-build hosting/bandwidth (§22 ch.08), bounty-equivalent (v1: credit + builds, $0 cash — stated in SECURITY.md so expectations are honest).
6. Community & support (owner Program; capped travel + infra): office-hours hosting, mentee hardware loans (deposit + return checklist — loaned units come back flashed to release + wiped with attestation §21 ch.08), status-page hosting (§20 below).

Monthly review ritual (15 min inside release-train review §15 calendar): actuals-vs-cap per category, forecast to quarter-end, overrun decisions (raise cap with reason / cut scope / move spend — "watch closely" without a number is not a decision). Two consecutive overrun months in any category triggers Arch review (same extend/demote/drop discipline as appendix-02B §2 — budgets get the gate treatment too).

## 19. Community governance — maintainer promotion & demotion (merit with receipts)

Roles: Contributor (any MR) → Area reviewer (merge rights in one area) → Maintainer (release-sign authority in that area + RACI §2 seat) → Arch (rotating, §7). Community-supported port status (§8 acceptance) does not confer merge rights — ports earn review rights by sustained quality, not by existing.

Promotion bar (all three, evidenced): (1) sustained merges (≥8 MRs in the area over 2 quarters, zero reverted-for-quality), (2) review citizenship (≥15 substantive reviews — checklist-linked, not LGTM — with nit-block rate 0 per review-sla sampling), (3) gate discipline (authored ≥1 gate-evidence artifact: power sheet, blessing log, ceremony co-sign, soak report — maintainers prove they can close the loop, not just open MRs). Nomination: any maintainer nominates with evidence links (quarterly review window — out-of-window nominations wait, no surprise coronations); approval: Arch + area maintainer unanimous (one veto = one quarter wait with written growth note — vetoes without notes are void).

Demotion (automatic triggers + human path): inactivity (no merged MR or review in 6 months → emeritus, rights suspended, restorable by one quarter of re-activity — no shame, no hearing); gate breach (merged red-CI, shipped testkey-adjacent bypass, clobbered user APN override — any one = immediate suspension + retro within 7 days, same hotfix-retro rule §1 ch.01); conduct (CoC breach → Program + Arch decide, reporter protected — process in CONTRIBUTING, referenced not duplicated). Demotions logged in `program/maintainers.md` history (dates + reason class — silent permission rot is how projects get ghosts with merge rights). Annual maintainer roll-call (ch.11 §15 calendar): active roster confirmed, emeritus offered re-ramp, backup coverage re-checked per §17 backfill rule (every area still has a backup with recent commits).

## 20. Communication cadence — internal + public status pages (silence breeds forks)

Internal (team): Mon standup 15 min (blockers only, §7) → Wed deep-dive 60 min (demo required) → Fri office-hours + bug-review 30 min (ch.10 pipeline: new P0/P1, quarantine expiries, gate vote) → monthly release-train review (bake metrics + TECH-DEBT delta + budget §18 + metrics §11) → quarterly OKR scoring + gate-readiness (§§12/15). Notes committed within 24h (`program/notes/<date>.md` — decisions + owners + dates; chat scrollback is not a record). Missed-notes week = bot files it (ch.11 §15 auto-filing — discipline automated).

Dogfood fleet channel (testers): weekly build note (what changed, what to watch, known issues with workarounds — same honesty rule as ch.09 §14, tester edition), daily-form nudges automated (§10 ch.10 form), P0 found → fleet notified within 24h with workaround-or-hold instruction (testers bricking silently while leads debate is the failure mode). Tester offboarding: exit survey (worst-thing + would-daily-drive + export check — feeds §16 post-v1 vote evidence).

Public (users + downstream): status page (hosted, linked from README + release notes): build health (nightly boot red/green), rollout stage per version (1/10/50/100% + halt banners with reason — halted rollouts disclosed, not discovered), security advisories (ch.08 §8 template, 90-day clock visible), EOL countdowns (≥90-day notice ch.01 §120-versioning rule). Update SLA: status page reflects rollout-halt within 4h, advisory within 24h of disclosure day, EOL notice same-day as decision. Release notes (ch.09 §14 template) publish before 10% stage (§14 honesty rule — notes are the public half of the rollout dashboard ch.09 §20). Incident comms (compromise/mirror-mismatch/fw-regression): acknowledge ≤24h public (what we know / what we don't / what to do — three headings, no fourth), update every 48h until closed, postmortem within 14 days (blameless template, linked from advisory — postmortems that never ship teach nothing).

Press/community inquiries: single contact (Program; backup named — inquiries answered ≤5 business days even if the answer is "no update yet"; ghosted press becomes adversarial press). Non-goal requests (GApps/Widevine, ch.11 risk-14): close-template reply citing ch.01 §§4/12 + ADR (kind, final, logged — rising counts trigger messaging review per risk-14, not per-reply improvisation).

## 21. EOL, sunset & export-exit operations (no stranded encrypted bricks)

EOL triggers (any one, decided at quarterly gate-readiness §15): SKU hardware unobtainable 2 quarters running (ch.11 risk-8 exhausted — no units, no testing, no blessing), upstream LTS EOL inside support window with no jump capacity (risk-13 trigger fired + jump declined by Arch review), blessed-carrier count drops to zero (carriers sunset CSFB/3G paths and our IMS never landed — risk-1 realized; data-only EOL edition offered instead of silent abandonment). Decision recorded as ADR (§14 format — consequences + revisit-when; EOL without an ADR is abandonment, not a decision).

EOL clock (binding, mirrors ch.01 §120-versioning rule): T-90 days public notice (status page §20 + release notes + fleet mail: last-supported version, export guide link, risks of staying), T-30 days final-signed image (security backports only, no features — the final image is a lifeboat, not a roadmap), T-day branch lock + transparency freeze (§17 ch.09 dirs stay fetchable ≥2 years — frozen bytes, verifiable bytes), T+180 days artifact retention review (canonical stays; community mirrors may drop with delist note per ch.09 §19 offboarding).

Export-exit (tested before the notice goes out — eol-export-runbook drill is the gate): `halide-export` (Settings → System → Export my data) produces portable archive + `MANIFEST.json` hashes + `halide-import --list` reader runnable on stock Debian 12+ (two-person verified: exporter + independent importer, per runbook). Crypto-erase-after-export offered inline (wipe-verify §21 ch.08 attestation shown — users leaving with proof, not hope). Enterprise fleets (P3): admin export API + wipe-attestation bulk collection (`fleet/<org>/wipes/` per fleet-management-guide) before MDM profile removal. Post-EOL support boundary committed in the notice (community-best-effort forums stay; signed OTAs stop; CVEs get `WONTFIX-EOL` with export advice — the boundary stated plainly so nobody discovers it via an unpatched lockscreen bug).

## 22. Contributor ladder (reporter → contributor → maintainer, rights at each rung)

Rungs (rights granted at each, revoked on the same terms §19 demotion — ladder and governance are one system): REPORTER (anyone filing issues: triage responses, `good-first-issue` assignment, no merge rights — reporters who file with logs per office-hours guidance §7 get priority attention, stated in CONTRIBUTING so effort is rewarded); CONTRIBUTOR (≥1 merged MR: CI visibility, review requests honored, porting-mentee eligibility §8 — contributors keep authorship + DCO sign-off on every commit, license-check §10 blocks unsigned work the same for founders and newcomers); AREA REVIEWER (merge rights in one area per §19 promotion bar: ≥8 MRs over 2 quarters zero-reverted + ≥15 substantive checklist-linked reviews + ≥1 gate-evidence artifact — reviewers approve within their area only, cross-area merges need the owning reviewer; nit-block rate sampled per review-sla §3); MAINTAINER (release-sign authority + RACI §2 seat: unanimous Arch + area-maintainer approval §19, 90-day probation with co-signs — maintainers sign gates §19 on named build IDs, own quarantine expiries ch.10 §11 in their area, mentor one contributor per quarter); ARCH (rotating quarterly §7: tie-breaks, ADR ownership §14, gate-calendar guardianship §15 — Arch ships code in their home area, ivory-tower Arch loses the seat).

Climbing evidence (all linked, never asserted): merge history (git log — sustained, not burst), review citizenship (review links with checklist references — LGTM-only reviewers don't advance), gate discipline (power sheet, blessing log, ceremony co-sign, soak report — closers advance, openers stall). Nomination windows quarterly (§19: out-of-window waits, no coronations; veto with written growth note or void). New-rung DoD: reviewer onboarding (merges 1 MR supervised + runs 1 gate-evidence procedure solo + passes support-log-script role-play ch.10-adjacent — reviewers who can't explain a gate can't guard it); maintainer onboarding (co-signs 1 ceremony §19 ch.08 + owns 1 monthly metrics line §11 with a red-response + completes ramp-kitBuddy duties for one hire §17). Emeritus path (§19 inactivity → rights suspended, restorable by one active quarter — celebrated returns, no shame). Ladder health metric (monthly §11): median days reporter→contributor + contributor→reviewer (rising medians mean onboarding or review-latency illness — cross-checked against MR-merge latency §11 before adding process).

## 23. Funding / sponsorship policy (what money can and can't buy: no gate-skipping)

Acceptable money (with guardrails): lab-hardware donations (logged in `program/ASSETS.md` §18 — donor named, no placement conditions on blessed SKUs; SKU blessing follows Phase-3 DoD ch.02 §1, never donor preference), CI/compute credits (owner Release §18 — credits don't change repro-parity rules ch.09 §2 or retention policy), event/travel sponsorship for office-hours and mentee loans (§18 category 6 — deposit + return + wipe-attestation rules apply to sponsored hardware identically), security-review funding (pentest/bounty-equivalent §18 category 5 — scope set by Security + Arch, findings SLA-closed regardless of sponsor; sponsor never previews findings before the advisory clock ch.08 §8). Unacceptable money (declined with the kind-final-logged close-template pattern §20/risk-14): feature-bounty-for-merge (payment for landing a specific MR — review and gates are not for sale; sponsored engineers contribute under identical review + gate rules, seniority of wallet buys zero), gate-skipping sponsorship ("fund us to bless carrier X by Friday" — blessed means measured ch.07 §11; money buys lab time and SIMs, never VERIFIED rendering), non-goal reversal sponsorship (GMS/L1 bundling funds declined per ch.01 §12 posture + ADR-004 §14 — bar named, not moved, regardless of amount), embargo-early-access payments (findings reach advisory on the same clock for everyone — ch.08 §8 template has no sponsor lane).

Transparency: every sponsorship ≥$500 (cash or kind) disclosed in `program/SPONSORS.md` (donor, amount/band, category §18, date, conditions verbatim — "no conditions" written explicitly when true) + monthly review line (§18 ritual carries a sponsors delta). Sponsored-engineer rule: employer named in MR trailers (`Sponsored-by:` — hidden sponsorship discovered later suspends merge rights pending retro §19 gate-breach path, kindly but firmly). Budget coupling: sponsorship never raises a quarterly cap silently (§18 overrun rule — cap changes are logged decisions at monthly review with reason). Annual sponsor audit (with EOL-policy review §15 calendar): active sponsors re-confirmed, lapsed entries archived with end dates (stale sponsor lists imply live influence that no longer exists — same STALE discipline as ch.01 §§15/19/26).

## 24. Trademark usage rules for ports (community freedom, project clarity)

HALIDE wordmark (cleared per §10 — record date) may be used nominatively by community ports ("HALIDE port for <neutral device name>" — factual, no endorsement implied); the following require written maintainer approval (request template in CONTRIBUTING, answered ≤30 days): use of the HALIDE logo on device packaging or boot animation variants (logo = endorsement signal, words ≠ logo), "Official HALIDE" / "Blessed" / "Supported" labels (blessed means Phase-3 DoD ch.02 §1 + §19-style sign — community ports are COMMUNITY per ch.02 §14 until promoted; mislabeled ports get one correction notice then a trademark-request-takedown, in that order, both logged), commercial pre-installs (seller ships HALIDE pre-flashed: must ship the exact signed release + SBOM link + export guide + EOL notice path ch.11 §21 — modified images sold as HALIDE are relabeled by rule, no exceptions for volume). Forbidden everywhere (no approval path): vendor trademarks in image names (`halide-<soc>` not `halide-oneplus` §10 rule restated — codenames internal REF-A until neutral public name), Play/Google marks implying certification (no-GMS posture ch.01 §12 extends to marks — "Google-compatible" claims need the compat-matrix link under ch.01 §29 substantiation rule), altered-logo derivatives presented as the project logo (fork branding must be visibly distinct — forks celebrated, confusion prevented).

Enforcement posture (kind, final, logged — same temperament as risk-14 close-template §20): private correction first (maintainer mail with the exact offending string + compliant alternative + 30-day window), public clarification second (status-page §20 note only if users are being misled about support/security posture), formal action last (reserved for commercial mislabeling affecting safety rows — telephony/emergency/OTA claims — where confusion has physical consequences). Port page requirements (each community port's README): support level badge (BLESSED/COMMUNITY/ARCHIVED ch.02 §14 — same vocabulary, same rendering honesty as UNTESTED §12), maintainer name + activity date (unnamed-maintainer builds demote §14 — trademark permission lapses with demotion), base release + patch level (stale-port security honesty — ports >60 days behind carry the patch-lag warning ch.01 §5 DoD security row). Annual mark review (with license operations §10): clearance re-checked, port-label audit (top-10 ports sampled for badge accuracy), violations log reviewed (rising counts trigger messaging help, not just enforcement — per risk-14 logic).

## 25. Annual program retrospective format (evidence in, decisions out, 4 hours max)

Schedule: within 30 days of v1-ship anniversary then yearly (gate calendar §15 — moved twice escalates per ch.01 §27; facilitator rotates among non-Arch maintainers — Arch answers questions, doesn't run the retro). Attendees: all §19 roles + 2 dogfood testers (one hacker, one non-hacker per risk-11 fleet-mix lesson — normie absence is how year-two surprises breed) + 1 community-port maintainer (P4 voice). Pre-reads (committed 1 week prior, no pre-read = reschedule not improv): metrics year-curves (§11: merge latency, CI-green, dogfood P0/P1 per 1k device-days, quarantine size, out-of-tree lines, patch-lag, maintainer roll-call deltas), gate history (pass/first-try rates + failed-gate root-cause weeks ch.00 rules), budget actuals-vs-caps (§18 — two-overrun categories named), risk-register movement (risks 1–14 opened/closed/realized with dates — realized risks without ADRs are the agenda), synthesis roll-up (ch.01 §30: top-3 churn drivers × cycles), EOL/demotion events (§21 + ch.02 §14 — each with its ADR or the retro's first finding writes itself).

Agenda (timeboxed): 30 min what shipped (demo clips, not slides — §7 demo rule applies to retros); 45 min what the numbers say (each metric owner states trend + red-response taken — metrics without responses flagged per §11); 45 min what hurt (top-5 incidents/postmortems revisited — repeat modes twice-a-quarter rule §18-adjacent checked against RMA/mode trends ch.02 §28); 45 min what we stop (exactly 3 stops named with owner + date — retros that only add commitments compound the backlog §25 cap teaches against; stops outrank starts); 45 min next-year bets (≤3 objectives shaped per §12 OKR-lite discipline — scored 0.0–1.0 next year, 0.7 = good); 30 min close (decisions read back + ADR assignments + calendar entries filed §15 — retro without calendar entries is journaling). Output (within 14 days, owner Program): `program/RETRO-<year>.md` (decisions + stops + bets + dissent — dissent recorded per ch.01 §19 spirit) + ADRs filed (§14) + gate-calendar + budget-cap updates (§§15/18 same MR or linked MRs — updates that drift apart rot). Health check on the retro itself (reported next year): kept-vs-rewritten plan ratio (ch.00 ownership rule) + last-year bets scored + stops verified stopped (a stop that quietly restarted is next year's first agenda item).

## 26. Spare-parts shelf depth (Owner: QA/lab · Phase: all — no schedule slips for a cable)

Lab stops for missing $8 cables kill more weeks than modem bugs. Shelf minimums below are binding; monthly release-train review (§15) checks the shelf count alongside bake metrics. Reorder fires at the reorder point, not at zero. Asset log `program/ASSETS.md` is the source of truth (unit label, serial, holder, purchase date per §18 category 1).

### Minimum shelf (per active REF SKU unless noted)

| Part | REF-A qty | REF-B qty | Reorder at | Lead-time cover | Notes |
|------|-----------|-----------|------------|-----------------|-------|
| test units (phones) | 3 (1 golden + 2 bench) | 2 | 2 / 1 | 6-week procurement | golden unit never leaves RF-bag except dogfood flash; bench units rotate soak |
| USB-C 3.x direct cables, 1m | 6 | 4 | 3 / 2 | 2 weeks | no hubs for flashing (ch.00 builder rule); failed cables join ch.02 §11 cable-log, then bin |
| UART adapters + pogo/tag-connect | 3 sets | 2 sets | 1 spare set | 3 weeks | one set per bench + one sealed spare; pinout card taped to each kit |
| PSU + current meter (calibrated) | 2 | 1 | calibration expiry -30d | 4-week cal loop | IDs feed ch.10 §8 power sheets + ch.00 gate sidecars; expired meter = red power data |
| thermal camera / thermocouples | 1 + 4 probes | shared | 1 probe spare | 2 weeks | ch.10 thermal sessions block without it |
| SIMs per blessed carrier | 2 active + 1 sealed | 1 active | 1 active | 1-week carrier ship | custody log per §18 cat.2 (which SIM in which unit) |
| NVMe scratch + SD cards (flash media) | 2× 256GB | 1× 256GB | 1 | 1 week | factory-station spares (ch.09 §10 ≤12 min target assumes working media) |
| ESD mats + battery bags | 2 / 4 | 1 / 2 | — | — | safety stock, checked at annual inventory (§15) |

Thresholds: cable failures >2/quarter triggers brand swap (ch.02 §11 stats decide, not anecdote). Unit loss (brick/RMA) triggers same-week reorder + incident note in `program/notes/` (brick without a note repeats). Golden-unit flash count logged per flash (eMMC/UFS wear is a real budget — retires at vendor TBW or 500 flashes, whichever first).

Shelf audit (monthly, QA/lab runs, 15 min):

```bash
./scripts/shelf-audit.sh --sku REF-A
# Expected:
# SHELF OK: units=3/3 cables=6/6 uart=3/3 psu=2/2 sims=3/3 media=2/2 probes=4/4
# REORDER: none (next cal expiry: PSU-03 2026-10-01, 47 days)
grep -c "^|" program/ASSETS.md
# Expected: row count >=28 (3 units + parts + holders); unlogged hardware = audit FAIL
```

Verification bullets: audit prints `SHELF OK` with all minimums met; reorder list empty or filed as purchase issue with owner + date; calibration IDs unexpired and matching gate sidecars (ch.00 templates); cable-log deltas reviewed (swap decision recorded or explicitly deferred with reason).

## 27. Release-train bake rules (Owner: Release + QA · Phase: 3c/3d, then monthly)

No build skips the bake. Promotion is by numbers at each stage, not by optimism. Version string `halide-<YYYYMMDD>-<sha12>` freezes at stage 1; any code change restarts at stage 1 with a new version (no hot-patching the bake).

### Bake stages (durations are minimums; failures extend, never compress)

| Stage | Population | Duration | Promote if | Halt if (any one) |
|-------|------------|----------|------------|-------------------|
| 1 lab soak | 3 bench units (REF-A) + VIRT | 72h | 0 unsolicited reboots, nightly-boot 3/3, power within envelope (ch.10 §8) | any reboot, any SOCKETS-audit deny, OTA-rollback demo fail |
| 2 dogfood | ≥8 testers (≥4 non-hacker per risk-11 §13) | 7 days | P0=0, P1 ≤2 per 1k device-days, export round-trip green | P0 found, VPN-egress fail, backup-restore fail, 2+ identical P1s |
| 3 staged rollout | 1% → 10% → 50% → 100% OTA | 2d / 3d / 3d / open | crash-free ≥99.5%, no new quarantine mode (ch.10 §11) | crash-free <99.0%, halt-banner reason filed, status page (§20) updated ≤4h |
| 4 blessed stamp | gate 3-release sign (QA+Security+Arch+Program) | 1 review | SBOM + license packet + ceremony refs complete | any missing packet item (SBOM, NOTICE, THIRD-PARTY, transparency dirs) |

Halt procedure (binding): Release files `program/rollout/<ver>-HALT.md` (reason, affected stages, build IDs, workaround-or-hold for fleet per §20) → status page banner ≤4h → fleet notified ≤24h → postmortem within 14 days (blameless, linked from advisory). Resume requires a new version string restarting at stage 1 (no resume-in-place after P0 or trust-row halt; P1-only halts may resume at stage 2 with QA+Release co-sign + ADR).

Bake dashboard queries (nightly CI posts to status page §20):

```bash
./scripts/bake-report.sh --ver halide-20260814-a3f9c1e2b4d6 --stage 2
# Expected:
# BAKE stage=2 ver=halide-20260814-a3f9c1e2b4d6 days=7/7 P0=0 P1=1/1k-days crash_free=99.7% verdict=PROMOTE-TO-3
./scripts/bake-report.sh --ver halide-20260821-7d4a55c19e02 --stage 1
# Expected:
# BAKE stage=1 ver=halide-20260821-7d4a55c19e02 hours=72/72 reboots=1 nightly=2/3 verdict=HALT (reboot log: logs/bake-<ver>-reboot.txt)
```

Verification bullets: version frozen at stage 1 (git tag matches image `ro.build.halide` + gate `build_id`); stage durations met on the calendar (short bakes reject at review); fleet mix enforced at stage-2 entry (hacker/non-hacker counts in the report); halt banners posted within SLA with reason (late disclosure = process fail per §20); blessed stamp only on full packet (no partial stamps, no inherited REF-A→REF-B blessings per ch.00 gates).

## 6. To grow 500K→900K (when ready)

Expand per-SoC appendices: `03-appendix-<sku>-dts.md`, `04-appendix-<sku>-hal-dumps.md` (`dumpsys`, `tinymix`, `camera characteristics`), `08-appendix-<sku>-avb-policy.md`, plus `carrier/<id>/perf.md` per carrier. Each appendix 20–40K chars; 6 appendices ≈ +180K. Then: per-bridge protocol specs (`bridges/<name>-protocol.md` with message schemas + fuzz corpora), per-sensor datasheets extracts, full sepolicy delta listings, and the `porting/NEW-SKU.md` worked example with real REF-A logs (redacted) — the worked example alone is ~40K of the most valuable chars in the set.

**Plan complete marker:** run `wc -m hybrid-os-plan/*.md`; sum ≥500,000 required. Current files are the dense v1 skeleton — expand each chapter's procedures/tables toward its budget header to reach the midpoint ~700K.
