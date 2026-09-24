# 01 — Vision, Requirements, Personas
**Budget: 50,000 chars · Phase: 0 · Owner: Product/Arch**

## 1. Vision statement

HALIDE is a true-hybrid mobile OS: one mainline Linux LTS+GKI kernel, Debian userland with systemd and Phosh as the primary human interface, and an AOSP 14/15 runtime in a privileged LXC container that provides HALs, telephony, camera, and Android app compatibility natively — not emulated, not dual-boot.

Success = a user can buy a supported ARM64 phone, flash HALIDE, and use it as their only phone: calls, SMS, data, camera, GNSS, push-adjacent notifications, 24h battery, OTA updates — while also having `apt`, a terminal, Firefox, and desktop-class tooling in their pocket. Android apps that don't require Play Integrity run; FOSS Linux apps run first-class.

## 2. Personas

**P1 — Privacy pragmatist (primary).** Wants Android app compat (banking, transit) without Google account lock-in. Accepts MicroG or sandboxed Aurora, wants firewall per-app, expects OTA that doesn't wipe. Acceptance: installs 10 Play-independent APKs, 9/10 work; battery within 20% of stock.

**P2 — Linux mobile hacker.** Wants `apt install`, systemd units, Wayland debugging, kernel tinkering. Accepts serial/UART, fastboot, `journalctl`. Acceptance: builds custom kernel module, DKMS equivalent flow documented, docs sufficient without asking maintainers.

**P3 — Enterprise / NGO deployer.** Fleets of 50–500 devices, needs reproducible images, signing, staged OTA, remote wipe, audit log. Acceptance: two builders reproduce image hash; key rotation runbook works; wipe verified via recovery.

**P4 — Upstream contributor.** Ports to new SoC. Acceptance: porting guide + DT overlay template + HAL checklist lets them reach Phase 1 in ≤4 weeks with only chat support.

## 3. Goals (v1)

1. Single kernel image per device family (GKI + vendor modules).
2. systemd PID1; Android container auto-starts, restarts on crash, logs to journal.
3. Phosh primary; Android launcher optional secondary.
4. Calling + SMS + LTE data + Wi-Fi + BT HFP/A2DP + camera stills + GNSS.
5. A/B seamless OTA with rollback, signed, encrypted data preserved.
6. Reproducible builds, SBOM per image, license manifest.
7. Security: AVB, dm-verity (strict), encryption by default, monthly patch SLA documented.

## 4. Non-goals (v1 — explicit to prevent scope creep)

- No Google Mobile Services / Play Integrity / SafetyNet bypass claims.
- No Widevine L1 (L3 only if trivially available).
- No VoLTE/IMS on all carriers (best-effort one carrier per device; document fallback to 3G/CSFB where legal).
- No x86_64 phone builds, no tablet/DTV/watch form factors as gates (may boot incidentally).
- No pKVM isolation, no dual-boot selector, no Windows-applet compat.
- No app store of our own; recommend F-Droid + Flatpak + apt.

## 5. Daily-driver Definition of Done (binding)

| Area | Gate |
|------|------|
| Boot | cold boot → lock screen ≤45s; 50 consecutive boots, 0 failures |
| Telephony | 20/20 MO+MT calls, 5 min each, no drop; emergency call routing verified per region build |
| SMS | 50/50 MO/MT incl. long/concatenated, airplane-toggle recovery ≤60s |
| Data | LTE attach ≤90s after boot; 1h iperf stable; hotspot to 1 client 30 min |
| Wi-Fi | WPA2/3 connect, roam once, 8h idle no disconnect; throughput ≥70% stock |
| BT | HFP call 10 min, A2DP 30 min, reconnect after toggle |
| Camera | rear stills 20/20, flash on/off, 1080p30 60s recording, no green frames |
| GNSS | cold fix ≤120s open sky, warm ≤30s; MAPS-equivalent app navigates 15 min |
| Power | 24h standby with SIM+Wi-Fi, ≥4h SOT browsing; suspend current within 2× stock |
| Stability | 7-day dogfood, 0 unsolicited reboots, ≤2 app crashes/day across top-10 apps |
| OTA | A→B→A cycle preserves data, rollback on failed boot verified by forced bad slot |
| Security | AVB green, verity enforcing, encryption on, patch level ≤60 days behind |
| Tests | kernel selftests pass, `cts-on-gsi`-subset green list recorded, no new SELinux denials vs baseline |

## 6. Functional requirements

**FR-01 Boot/init.** systemd PID1; `halide-android.service` starts LXC after `/dev/binder`, `/dev/ashmem`, graphics nodes ready. Restart policy with backoff. Boot animation shows stage (kernel → systemd → android → shell ready).

**FR-02 Android runtime.** `sys.boot_completed=1` within 120s of container start. `logcat`, `dumpsys` reachable from host via vsock/bridge. App install via F-Droid/Aurora; intents to open Android apps from Phosh drawer.

**FR-03 Identity/permissions bridge.** Single consent prompt maps to both PolicyKit/xdg-permission-store and Android runtime permission. Contacts/calendar shared via EDS↔Android provider sync (one-way v1 acceptable with documented direction).

**FR-04 Networking single-stack.** NetworkManager owns Wi-Fi/LTE; Android sees netd via translation shim, no double NAT. VPN from either side covers both (document which side owns TUN).

**FR-05 Audio single-server.** PipeWire owns routing; AudioFlinger→PipeWire bridge. Call audio priority preempts media. Echo/noise path documented per device.

**FR-06 Updates.** A/B slots, `update_engine`-compatible payloads, staged rollout, changelog shown in Settings.

**FR-07 Recovery.** Minimal recovery with ADB sideload, factory reset, log export to USB.

## 7. Non-functional requirements

- **Performance:** app cold start ≤2× stock; Phosh frame drops <5% in scroll test; touch→photon <100ms for Android bridge.
- **Power:** modem + AP suspend residency >90% overnight; wakelock dashboard (`halide-power top`).
- **Storage:** image ≤8GB compressed; data encryption AES-256-XTS; fstrim scheduled.
- **Reliability:** MTBF ≥168h dogfood; watchdog reboots with ramoops preserved.
- **Maintainability:** one manifest pins kernel+AOSP+Debian snapshot; `repo forall -c git log` reproducible.
- **Accessibility:** Phosh a11y stack intact; font scaling; screen reader for native apps (Android TalkBack best-effort).
- **Localization:** top-12 locales for shell; Android locale follows system locale.

## 8. Compliance & legal

- GPL-2.0 kernel sources published with each release + build scripts (same-day SLA).
- Apache-2.0 AOSP attributions preserved; `NOTICE.html` equivalent in Settings → About.
- No redistribution of Google proprietary blobs; pull from device or document extraction.
- Carrier certification is out of scope for v1; label builds "experimental, emergency-calling verified on [carrier] only".
- Export control: standard cryptography (OTA signing, TLS) — document jurisdiction note for distributors.

## 9. UX principles

- One home (Phosh). Android apps appear as icons with a subtle badge, not a separate "mode".
- One settings search covering both stacks (map Android settings intents to GNOME Settings panels where possible).
- One update prompt. One permission prompt. One share sheet (v1: share from Android→Linux guaranteed; reverse best-effort).
- Terminal is first-class but never required for daily use.

## 10. Risks to requirements (summary; full register in ch.11)

- Modem IMS/VoLTE blobs may never allow third-party OS calling on some carriers → mitigate with one blessed carrier per device + CSFB documentation.
- Camera ISP tuning closed → mitigate with open-source HAL + reduced-quality acceptance for v1.
- Power parity hard → mitigate with suspend-blocker audit sprint before Phase 3 gate.

## 11. User stories (acceptance-linked)

P1 stories: (a) "I install my bank app from Aurora, log in, receive OTP via SMS auto-fill, approve a transfer" — E2E tested with 2 real banking flows per release (redacted screen-recording archived, no credentials stored). (b) "A transit app with maps loads my city, GNSS navigates a 15-min route" — tested on REF-A with GPSTest side-by-side. (c) "I revoke location from a flashlight app in one place and both stacks lose it" — permission-sync test (ch.05 §9). P1 app-compat matrix (`compat/TOP-100.md`): top-100 Play-independent APKs per region, each graded WORKS/DEGRADED/BLOCKED with reason (needs-GMS / needs-Integrity / needs-L1 / works) — BLOCKED-by-Integrity apps are listed honestly with the technical reason, never "coming soon" without a bug ID.

P2 stories: (a) "I `apt install mosh`, `systemctl --user enable` my agent, `podman run` my container" — verified on-device (no chroot tricks). (b) "I build an out-of-tree module against installed headers and `insmod` it on eng" — headers package + Kbuild path documented with one worked example (`hello-halide` module in repo). (c) "I capture a full boot trace with UART + ftrace without asking anyone" — ch.03 §17 tooling present on-device (eng) or via `halide-debug` bundle command.

P3 stories: (a) "I enroll 50 devices with my keys, staged OTA, and wipe one remotely with attestation" — fleet runbook in ch.09 §10 + wipe attestation (ch.08 §9). (b) "My auditor gets SBOM + CVE dispositions + build hashes for version X" — artifacts checklist (ch.09 §11) satisfiable from public release page alone.

P4 stories: (a) "I reach UART shell on my SDM845-adjacent board in week 1 following porting/NEW-SKU.md" — doc tested by a non-maintainer annually (fresh-eyes port of a neighboring SKU, findings filed as doc bugs).

## 12. Google-services position (explicit, reviewed by counsel-or-leads)

v1 ships no GMS, no Play, no proprietary Google apps. MicroG (GNSS/location backend + push) is optional post-install (documented sideload, not preinstalled — preinstalling changes the legal/privacy posture; the choice stays with the user). Sandboxed Aurora Store is documented for Play-independent APKs with a warning that Play Integrity–gated apps (banking, some games) may refuse on any non-certified OS — the compat matrix records this per app instead of promising bypasses. Push notifications: host-side polling + Android `FCM`-less apps work; MicroG cloud-messaging is best-effort with battery-impact note. This section is load-bearing for trust: never market "degoogled but everything works" — market "documented compat, measured gaps".

## 13. Release & support policy

Versioning `halide-v<major>.<minor>.<patch>+<sku>` (major = breaking OTA/partition change, minor = monthly, patch = hotfix). Support window: N + N-1 monthly branches (security backports only to N-1; features ride N). EOL announcement ≥90 days with final-signed image + export-your-data guide (no stranded encrypted bricks — export tooling tested before EOL notice). Blessed-carrier list versioned with releases (a carrier working in v1.3 stays working in v1.4 or it's a regression, not a footnote).

## 14. Accessibility & localization depth

a11y: Phosh screen-reader + high-contrast + large-text verified on native path (3 scripted tasks by a tester using SR only: place a call, send SMS, take photo — pass/fail recorded); Android TalkBack best-effort with per-release note (no claims). Haptics accompany all permission/call alerts (deaf-blind-adjacent redundancy, cheap to add). i18n: top-12 locales for shell + installer; RTL smoke (one RTL locale screenshot-diff in CI); Android locale follows host (ch.05 §9 prop-bridge) with per-locale fallback chain documented; input methods (multilingual keyboard + CJK) installed but dormant until user enables (image-size discipline from ch.09).

## 15. Compat-matrix operations (`compat/TOP-100.md` — the trust engine, run like a lab)

List construction (per region, refreshed semi-annually): top-100 free Play-independent APKs by category quota (banking 10, transit 10, messaging 10, maps/nav 5, media 10, shopping 10, gov/public 10, health 5, food 5, misc 25 — quotas prevent all-games lists). Per-app row: package, version tested, source (Aurora/F-Droid/direct), grade (WORKS = full flow incl. login+push-equivalent; DEGRADED = works with named gaps; BLOCKED = reason code: NEEDS-GMS / NEEDS-INTEGRITY / NEEDS-L1 / NEEDS-IMS / CRASH-<bug>), tester, date, device+build. Grade changes require re-test on current release (stale grades expire 90 days → `STALE` badge, never silently trusted). BLOCKED-by-INTEGRITY rows link the honest explanation (ch.01 §12) + any lawful workaround status (none promised). P1 acceptance (ch.01 §2: 9/10 of user's own 10) measured in dogfood exit interviews against this matrix (hit-rate reported per release — "v1.4: 83/100 WORKS, +4 vs v1.3").

## 16. NFR measurement methods (every non-functional requirement names its ruler)

Performance (§7): app cold-start measured by `halide-app-launch --cold <pkg> ×10` (median + p90, screen-offNamespaces between runs to defeat cache warmth lies); Phosh frame drops via `frame_timeline` 200-frame capture (ch.06 §10 matrix); touch→photon via SEQ-joined CSV (ch.06 §7 latency method — one method everywhere, not three). Power (§7 DoD rows): power-results-template sheets (method footnotes mandatory, ch.10 §8 calibration). Storage: `df` + `dumpexfat`-equivalent image-size audit per release (8GB compressed cap from §7 tracked in CI — oversize fails the build with the fattest package named). Reliability: MTBF from dogfood fleet telemetry (opt-in) + lab soak logs (ch.10 §5 taxonomy counts — MTBF computed from P0 timestamps, not estimated). Maintainability: manifest-drift check (ch.09 §1 `verify` green = proof) + out-of-tree line trend (ch.03 §20 graph). Accessibility: SR-scripted 3 tasks pass/fail ( §14) recorded per release with tester + SR version (different SR versions behave differently — version recorded or the pass is anecdotal). Localization: per-locale screenshot-diff for top-12 (CI golden set — untranslated-string spill detected as pixel diff in RTL smoke + `gettext` untranslated-count metric trending to 0).

## 17. Scope-change control (requirements change — chaotically by default, by process here)

Change classes: CLARIFICATION (wording, no behavior change — Product + area owner sign, 48h), EXTENSION (new behavior within DoD spirit, e.g., second carrier blessed — Arch review + gate-impact note + milestone re-plan if >1 week), REDUCTION (cut a gate, e.g., drop BT-SCO v1 — Arch + QA + Program sign + DoD table amended with strikethrough + rationale + public notes updated same MR — silent cuts discovered later destroy trust), PIVOT (non-goal reversal, e.g., "actually ship GMS" — full re-brainstorm per superpowers process + new threat-model pass + timeline re-baseline; pivots are rare enough that each gets a retrospective). Every change updates: this chapter (DoD table is versioned — `git log` on §5 tells the requirements history), affected test IDs (ch.10 allowlists), risk register (ch.11 — scope changes move risks), and the release-notes KNOWN-ISSUES section template (ch.09 §14). Unrecorded scope (code merged beyond written requirements) is treated as a process P1 (found in review via requirements-trace check: every behavior MR links its FR/NFR id — no link, no merge).

## 18. Launch-day readiness (v1.0 ships when this list is green — not when the date arrives)

[ ] All Phase-3 gates signed per ch.00 gate rules (no verbal gates, REF-B independent).
[ ] Dogfood exit interviews show P1 9/10 acceptance (ch.01 §2 + §11 stories evidenced, not asserted).
[ ] Compat hit-rate published + trending up 2 releases (ch.01 §15 ops running, not launched-at).
[ ] Support script dry-run with confused-user roleplay green (support-log-script verification).
[ ] Factory flash by non-engineer ≤12 min (ch.09 §10) + first-boot ≤6 min (runbook-firstboot §3) demonstrated same week.
[ ] Rollback-on-bad-OTA + crypto-erase canary + relock drill all green within 30 days (no stale safety proofs).
[ ] Security: zero OPEN-without-bug threat rows (threat-model verification), pentest findings SLA-closed (attack-test §6), CVE bins empty-or-dispositioned (08 §15).
[ ] Transparency repo complete + user-verification procedure tested by second person (ch.09 §17).
[ ] EOL/export drill green (eol runbook verification — exit proven before anyone enters).
[ ] Launch notes use ch.09 §14 template with zero fluffy known-issues (review-sla nit-rule cited if needed).
Slip rule: any red pushes the date with the red item named publicly (internal + dogfood channel) — silent slips rot trust faster than late dates.

## 19. Stakeholder sign-off process (no verbal gates — signatures or it didn't happen)

Signatories per gate: Product (DoD + scope), Arch (FR/NFR + non-goal changes), QA (measurement methods §16), Security (threat rows + GMS posture §12), BSP/Hardware (device claims). Sign-off artifact: `signoffs/<release-or-gate>.md` with per-signer lines (`I <name> (<role>) sign <gate-id> on <build-id> — exceptions: <none|BUG-ids>`). Rules: (1) Sign on a named build ID, never "latest" — `halide-v1.3.2+refA` not "nightly". (2) Conditional sign lists blocking BUG IDs; unresolved conditionals = red in gate review (ch.00 rules). (3) Expiry: sign-off older than 30 days or 2 releases (whichever first) is STALE — re-sign required (prevents "we signed in March, ship in September"). (4) Dissent recorded: any signer may file `DISSENT:` paragraph that ships in release notes internally — dissent suppressed is a process P1. Meeting format: 60-min gate review, pre-read (DoD evidence links) 48h prior; no pre-read = auto-slip one week (the discipline that makes evidence real). Quorum: all 5 roles or reschedule — proxy sign by chat message is void. Emergency hotfix path: 3/5 signs + retro within 7 days with full evidence (hotfix without retro loses the fast path for 90 days).

Escalation ladder for sign refusal: owner proposes scoped exception (exact gates waived + compensating test + expiry release) → Arch adjudicates within 72h → Program records in risk register (ch.11) with owner + date. Silent shipping past a refusal = revert + postmortem (ch.11 pattern).

## 20. Requirements traceability matrix ops (every FR has a test or it is a wish)

Matrix lives at `reqs/TRACEABILITY.csv` with columns: `req_id,req_text_hash,design_ref,test_id(s),gate,responsible,status`. Population rules: each FR-01..07 + NFR rows from §5 DoD table get ≥1 test ID in ch.10 (format `HALIDE-<area>-<NN>`); each persona story (§11) maps to ≥1 E2E script (P1-bank-flow → `e2e/bank-otp.sh` redacted variant in CI with mock). Maintenance: every behavior MR must touch TRACEABILITY.csv (add row or update test_ids) — CI job `req-trace-check` greps the MR diff for `FR-[0-9]|NFR|DoD` reference and fails bare-behavior merges (§17 rule enforced in code, not culture). Coverage audit monthly: script `scripts/req-coverage.py` reports orphan reqs (no test), orphan tests (no req), stale hashes (req text changed without test update — hash mismatch flags it). Targets: 0 orphans at Phase gates; ≤5% stale between gates with per-row BUG link.

Bidirectional discipline: test failures link back to req rows in the failure report (`FAILED HALIDE-TEL-04 → FR-02/RIL + DoD-telephony-row`); triage without the back-link is bounced (prevents "fixed the test, broke the requirement"). Tooling: CSV is source of truth (not a wiki — diffable, reviewable); generated `TRACEABILITY.html` published per release for auditors (P3 story §11(b) consumes this page directly).

Example rows:

```
FR-02,9f3a…,ch.04§5+ch.05§2,HALIDE-AND-01;HALIDE-AND-02,Phase-2,Android-lead,PASS-v1.3.2
DoD-telephony,41bc…,ch.07§2,HALIDE-TEL-01..05,Phase-3,QA-lead,3/5-green
P1-bank-otp,c712…,ch.01§11(a),e2e/bank-otp-mock,Phase-3,Product,MANUAL-pass-2026-05
```

## 21. Launch-blocker triage (what stops the ship, who decides, how fast)

Blocker definition (all three required): (a) violates a Phase-3 DoD gate row (§5) or a signed exception's expiry, (b) reproducible on BLESSED SKU by second person (no single-machine ghosts), (c) no documented workaround a P1 user can perform in ≤5 min. Non-blockers that feel like blockers (ugly icon, slow-but-within-2× app start, missing Phase-4 feature) are `LAUNCH-KNOWN` (release-notes entry via ch.09 §14 template, not a slip).

Triage cadence: daily 30-min blocker review in launch window (last 6 weeks), same 5 roles as §19. Input queue: `bugs/LAUNCH-BLOCKERS.md` (sorted: P0-blocker / P1-launch-known / P2-deferred with the exact DoD row cited per P0 — uncited P0s demoted on sight). SLA: new P0 triaged ≤24h (blocker vs known vs need-repro), P0 fix-or-exception ≤7 days (exception follows §19 scoped-exception path with compensating test), P0 re-test ≤48h after fix build (stale fixes re-open automatically). Blocker burn-down published twice weekly (counts + oldest age + per-owner load — overloaded owner triggers re-assignment, not heroics).

Exception path (shipping with a red): requires (1) named DoD row waived, (2) user-visible release-note text (no euphemism — "calls drop on carrier X after 8 min" not "telephony improvements ongoing"), (3) compensating guard (e.g., blessed-carrier list narrowed, warning banner in first-boot), (4) expiry release where the waiver dies (waivers without expiry are cuts — §17 REDUCTION process applies instead). Waiver signed by all 5 (§19) — majority waivers don't exist for safety rows (telephony/emergency/OTA-rollback/security require unanimity; a single safety veto holds the ship).

Slip communication (§18 slip rule implementation): within 24h of slip decision, publish: red item + owner + new date + what users/devices are affected + what still works. Template in `releases/SLIP-NOTE.md`. Silent-slip postmortem triggered if the note is >48h late.

## 22. Competitor/cost analysis honesty rules (position without lying)

Permitted comparisons (measured, cited): vs stock Android (same SKU, same ambient/modem-fw — power §7 + perf §16 methods), vs postmarketOS/Droidian/Ubuntu Touch (feature-presence table, not speed claims unless same-device measured), vs GrapheneOS (threat-model scope difference stated: our hybrid convenience vs their hardened single-stack — different goals, say so). Forbidden patterns (review-bounced): battery claims without meter traces, "faster than" without p50+p90 + build IDs, security superlatives ("most secure" — use the threat-model rows instead), compat percentages without matrix date + denominator ("92% works*" with footnote `*of 48 tested` = trust arson).

Cost-of-ownership table (maintained per release in `releases/COST.md`): device purchase (used/new REF-A/B street price), spare battery/panel (lab shelf prices §13), build/CI cost per release (compute hours × rate), signing/HSM amortization, support load (hrs/week dogfood × headcount). Purpose: enterprise P3 (§2) quotes + EOL decisions (§13) + honest "is this sustainable" review annually. Numbers estimated where unknown with `EST` flag + method note — fake precision (two decimals on guesses) rejected in review.

Positioning one-pager (ships with every release, `releases/POSITIONING.md`): what HALIDE is (hybrid pocket computer + daily-driver phone on blessed SKUs), what it is not (§4 non-goals restated in plain language), who should not install (needs Play Integrity banking as primary, needs L1 Netflix HD, needs guaranteed VoLTE on unblessed carrier — named explicitly), and where to verify claims (compat matrix date, power sheets, security disclosure page). Marketing copy diffed against this page in review — drift = MR blocked.

## 23. Dogfood exit-interview protocol (acceptance evidenced, not asserted)

Sample: ≥15 P1 users + 5 P2 + 3 P3-deployers per release cycle, each with ≥14 days on the candidate build (short-stint opinions don't count toward the 9/10 bar §2). Interview script (`reqs/EXIT-INTERVIEW.md`, versioned — script changes logged so cross-release comparisons stay valid): (1) user's own top-10 apps enumerated by the user before grading (prevents tester-suggested lists), (2) per-app WORKS/DEGRADED/BLOCKED grading with reason codes shared with compat matrix §15 (same vocabulary both places — interview rows feed matrix re-tests), (3) P1 stories §11(a–c) replayed live (bank-OTP with mock credentials rig, transit nav 15-min, permission-revoke both-stacks check with timer), (4) battery narrative (standby nights + SOT days from Settings → Power, cross-checked against meter sheets where lab units overlap), (5) open prompt ("what almost made you flash back to stock?" — the almost-churn answer outranks satisfaction scores).

Scoring: P1 pass = ≥9/10 own-apps WORKS-or-DEGRADED-with-tolerated-gap (DEGRADED counts only if the user states the gap is tolerable unprompted — prompted tolerance is interviewer bias, recorded as FAIL with note). Results table `reqs/EXIT-<ver>.csv` (anonymous IDs, device SKU, build ID, per-app grades, story pass/fail, churn-risk quote redacted of PII). Release rule: hit-rate + story pass-rates published in release notes (same numbers QA signed §19 — interview CSV is the evidence behind the signature). Non-response bias guard: response rate reported (e.g., "17/23 completed" — 40% response with 100% pass is not 100% pass, stated as such).

## 24. EOL/export drill procedure (exit proven before anyone enters)

Annual drill (calendar-bound, owner Product + Platform): take sacrificial REF-A on current release, run the full EOL sequence from §13 (announcement draft + final-signed image + export-your-data guide) as if the SKU retired tomorrow. Steps: (1) build final-signed image for the SKU (signing ceremony ch.09 §15 path — drill uses production keys flow with `DRILL` watermark so no confusion with real finals), (2) `halide-backup` full export (§12 ch.05 — contacts/SMS/photos/home manifest + Android package manifest), (3) factory-reset + crypto-erase canary (ch.08 — verify erase attestation line), (4) restore export onto a second unit (different flash wear — restores that only work on the source unit are not exports), (5) verify counts (contacts/SMS exact per ch.05 §14 invariant, media hash-sample 100%, home manifest dotfiles exact), (6) publish drill report (`releases/EOL-DRILL-<date>.md`: timings, gaps, doc fixes filed as bugs — drill findings are bugs, not observations).

Pass bars: export completes without engineer assistance beyond the guide (P3 auditor persona §2 reads the guide cold — engineer-present success doesn't count), restore verified by second person, total user-data-loss events zero (any loss = drill FAIL + P0 against the export tooling, not "user error"). Failed-drill rule: two consecutive drill FAILs trigger an Arch review of the data model (§6 separation + §12 backup scope — persistent export failures mean the storage design owes an answer, not the docs).

## 25. Requirements-review cadence & Definition-of-Ready (gates have office hours)

Cadence: requirements review every 2 weeks outside launch window, weekly inside (same 5 roles §19; 45 min; pre-read = TRACEABILITY delta §20 + blocker delta §21 + compat hit-rate delta §15). Definition-of-Ready for any FR/NFR change (§17 classes): problem statement (which persona story fails today, with evidence link — no evidence, no discussion), measurement plan (§16 ruler named + test IDs reserved in ch.10 before the change merges, not after), gate-impact note (which DoD rows move + which release train carries it), rollback statement (what revert looks like if the change breaks dogfood — changes without a revert story are experiments, scheduled as spikes with timeboxes, not committed as requirements). REDUCTION-class changes additionally require the strikethrough DoD amendment + public-notes update in the same MR (§17 — the MR template has checkboxes for both; unchecked = CI fail). PIVOT-class changes require a fresh 60-min brainstorm recorded (attendees + options considered + why now — pivots without written alternatives re-litigate forever).

Backlog hygiene: requirements backlog (`reqs/BACKLOG.md`) capped at 30 live items (overflow parks in `reqs/PARKED.md` with revisit dates — unbounded backlogs pretend everything is planned; the cap forces the prioritization conversation quarterly). Each backlog item carries persona + story link (§11), size estimate (S/M/L with M ≈ 1 engineer × 2 weeks — estimates revisited after completion, calibration error tracked), and a kill condition ("drop if camera-ISP docs don't arrive by <date>" — kill conditions executed, not extended twice; second extension needs Arch sign with written reason).

## 26. Persona-data refresh (personas rot — re-interview or retire them)

Annual refresh (owner Product, scheduled with compat-list refresh §15): 5 fresh interviews per persona (non-dogfood recruits where possible — dogfood regulars develop stockholm syndrome for workarounds; fresh eyes price the workaround honestly), top-10 app lists re-sampled (category quotas §15 cross-checked — persona drift shows first as app-list drift), acceptance bars re-priced (9/10 rule §2 revisited only with evidence: two consecutive cycles ≥95% pass rate may tighten to 10/10-aspirational; two cycles <70% triggers scope review §17, not bar-lowering — bars move on capability, not disappointment). Stale-persona rule: any persona with zero refresh interviews in 18 months renders `STALE` in the doc header (same vocabulary as stale compat grades §15 and stale sign-offs §19 — STALE means the same everywhere in this plan). P4-contributor health metric: median weeks-to-Phase-1 for the last 3 community ports (target ≤4 per §2; misses file doc-bugs against `porting/NEW-SKU.md` with owner + date, not vibes).

## 27. Gate-calendar hardening (reviews that move twice die quietly — prevented here)

All §19/§25 reviews + §24 EOL drill + §26 persona refresh live on a shared gate calendar (`program/GATE-CALENDAR.md`, quarters ahead): any gate review moved twice consecutively escalates to Program + Arch with written reason (same anti-drift rule as kernel ledger reviews ch.03 §27 — rescheduling is a signal, tracked not judged); quorum rules restated per event (5-role gate reviews need 5 roles — proxy-by-chat void §19); missed-event backfill SLA 14 days (missed calibration/refresh/drill without backfill date = process P1 filed by whoever notices — filing is praised in retro, silence is not neutral).

## 28. Pricing / cost-of-goods honesty (BOM + lab amortization in public notes)

Street-price honesty starts from `releases/COST.md` (§22 companion, maintained per release by Product + QA): device purchase (REF-A/REF-B new + used street price sampled from 3 listings, date-stamped — prices drift, undated prices mislead), spare panel/battery shelf prices (ch.02 §13 shelf), per-unit bring-up consumables (UART adapter share, USB-C cable attrition per ch.02 §21 cable-log burn rate, thermal paste/tape for open-device work), carrier SIMs + top-ups per blessed carrier (ch.11 §18 category 2), build/CI cost per release (builder hours × cloud-or-power rate + artifact retention overage), signing/HSM amortization (device cost ÷ 36 months ÷ releases-per-month — a $800 HSM over 24 releases is $33/release, stated not hidden), support load (dogfood hours/week × headcount from ch.11 §7 cadence). No per-unit HALIDE license fee v1 (stated explicitly — absence of a fee is itself a pricing claim that must stay true; if a fee ever appears it goes through §17 PIVOT, not a footnote).

Rules: every cost line carries `EST` or `MEASURED` flag + method note (§22 fake-precision rule extended here — `EST $4.10` rejected, `EST ~$4` accepted). BOM tables never mix one-time lab capex with per-device cost without labeling both columns separately (lab amortization per supported device = total lab capex ÷ active blessed units from `program/ASSETS.md` — the number that answers P3 "what does fleet entry really cost"). Enterprise quotes (P3 §2) cite COST.md revision hash, never a chat number. EOL decisions (§13) must reference COST.md trend (supporting a SKU whose spare-panel price tripled is a budget decision with a number attached, not loyalty).

## 29. Press / launch messaging guardrails (claim-substantiation rule: every claim links a test artifact)

Claim-substantiation rule (binding on `releases/POSITIONING.md`, launch notes, README badges, talks, and any reply to press): every externally-visible performance/compat/security/battery claim links a named test artifact with build ID + date (compat matrix date §15, power sheet ch.10 §8, threat-model row ch.08, DoD evidence §18). Claim without link = draft, not publishable — review bounces it under the §18 fluffy-known-issues nit-rule extended to all claims. Banned sentence shapes (auto-flagged in review): "fully compatible" (use hit-rate + denominator + date), "daily driver for everyone" (use blessed-SKU + blessed-carrier scope), "secure/degoogled" as absolutes (use threat-model scope + §12 services posture), "long battery life" without meter trace (use standby-hours + SOT + ambient per ch.10 §8), "supports <carrier>" without matrix row (use ch.07 §11 VERIFIED/UNTESTED rendering — UNTESTED-bold has one font everywhere per ch.02 §22).

Launch-kit checklist (owner Product, refreshed per release): one-paragraph description (diffed against POSITIONING.md — drift blocks MR §22), 5 screenshots (Phosh home, Android app badged, Settings→About with patch level, OTA prompt, permission prompt — no mockups presented as screenshots), compat hit-rate line with matrix link, power line with sheet link, non-goal restatement (§4 in plain language: no GMS/Integrity/L1/guaranteed-VoLTE — reporters who discover non-goals themselves write adversarial pieces), known-issues excerpt (top 5 from ch.09 §14 template, unedited wording), contact + response SLA (ch.11 §20 single contact, ≤5 business days). Embargo/pre-brief rule: no performance numbers shared pre-release without the linked artifact existing in-tree (embargoed claims that later fail verification are retractions, not corrections — treated as process P1).

## 30. User-exit interview synthesis process (from 23 interviews to 3 decisions)

Inputs per cycle (§23 `reqs/EXIT-<ver>.csv` + compat deltas §15 + support-log-script pain tags + dogfood P0/P1 counts ch.10 §5): synthesis owner Product, 2-week window post-dogfood, workshop 90 min with the §19 five roles (no synthesis by one author in a corner — single-author synthesis reintroduces the bias §23 guards were built to remove). Method: (1) affinity-cluster the "almost made you flash back" quotes (§23 open prompt ranked first — churn quotes outrank satisfaction scores by rule, not sentiment), (2) join per-app BLOCKED rows to compat reason codes (NEEDS-INTEGRITY vs CRASH-<bug> drive different decisions — conflating them produces "fix compat" mush), (3) cross-check battery narratives against meter sheets (narrative-only battery regressions without meter confirmation go to re-measure, not to roadmap), (4) score each P1 story §11(a–c) pass-rate separately (a release can pass 9/10 apps while failing permission-sync — the roll-up must not hide it).

Outputs (committed as `reqs/SYNTHESIS-<ver>.md`, linked from release notes): top-3 churn drivers with owner + disposition each (FIX-in-next / DOC-workaround / ACCEPT-with-positioning-update §22 / NEEDS-PIVOT §17 — every driver gets one, "monitor" without an artifact is not a disposition), compat-matrix re-test queue (BLOCKED↔DEGRADED transitions filed as test tasks with device+build, not wishes), one messaging fix (POSITIONING.md or support script wording changed per cycle — interviews that never change messaging aren't being read), one backlog kill-or-commit (synthesis retires or funds exactly one `reqs/BACKLOG.md` item §25 — unbounded growth ends here). Non-response bias restated in synthesis (§23 response rate carried forward — "17/23" travels with every quoted pass rate). Dissent paragraph allowed (same rule as §19 — suppressed dissent resurfaces as a fork).

## 31. Annual vision review (what triggers a vision change vs a plan change)

Cadence: one 2-hour session annually (owner Product + Arch, all §19 roles present, scheduled on the gate calendar ch.11 §15 — moved twice = escalate per ch.01 §27). Pre-read (48h): synthesis roll-up (3 cycles), persona refresh §26 (drift evidence), compat hit-rate trend (§15 — two releases direction), COST.md trend (§28 — sustainability), post-v1 vote data (ch.11 §16 evidence), non-goal pressure count (ch.11 risk-14 occurrence log — rising counts are the canary). Decision classes (recorded as ADR ch.11 §14, newest-first): VISION-HOLD (reaffirm §§1–4 verbatim with re-sign — holds are decisions with dates, not inertia), PLAN-CHANGE (DoD/FR/NFR/scope moves via §17 classes — vision untouched, execution corrected), VISION-CHANGE (alters §1 success definition, §2 persona set, or §4 non-goals — requires the §17 PIVOT path: fresh brainstorm + threat-model pass + timeline re-baseline + full §19 re-sign; vision changes without PIVOT rigor are scope creep with better branding).

Triggers that force the question (not the answer): two consecutive dogfood cycles <70% P1 pass (§26 scope-review trigger), blessed-carrier count dropping to zero (ch.11 §21 EOL trigger adjacent — vision "daily-driver phone" without a carrier is fiction), compat hit-rate plateau ±2% over 3 releases with INTEGRITY-blocked share >40% (signals the no-GMS posture §12 caps the vision — confront, don't footnote), COST.md per-device amortization doubling (vision unsustainable at current SKU strategy — change SKU, funding per ch.11 §23, or scope), maintainer bench collapse (ch.11 risk-4 realized — vision requiring 4-person core with 1 person is a different vision). Output: `vision/ANNUAL-<year>.md` (decision class + evidence links + dissent + next-review date) + updated sign-off sheet (§19 format — annual holds expire like gate signs, 12-month max). Review inputs archived with the record (synthesis docs, COST.md revision hash, compat-matrix date, persona interview IDs redacted of PII) so a future reader can replay the reasoning without reassembling context from chat scrollback; any vision-change ADR additionally lists the superseded paragraphs of §§1–4 by number and carries the re-baselined 36-week-style milestone sketch so the cost of the turn is visible beside the rationale. Attendance and quorum recorded in the annual file (absent roles submit written positions within 7 days or are marked ABSENT — absent-silence never reads as consent).

## 32. Feature-request intake SLA (requests welcomed, scope guarded, silence forbidden)

Intake lives in exactly one tracker (`requests/` issues — forum threads, chat messages, and hallway promises are pointers, not requests; a request without an issue ID does not exist for planning). Rationale: §4 non-goals + §17 change control + §25 backlog cap only work when every ask is countable, linkable, and dispositioned in public. Every request follows the same pipeline: TEMPLATE → ACK → TRIAGE → DISPOSITION (ACCEPT-to-backlog / DOC-workaround / DECLINE-with-reason / NEEDS-PIVOT), with SLA clocks that run on business days and are visible on the issue itself (`SLA: ack-due <date> / triage-due <date>` label line maintained by bot, not memory).

Issue template (mandatory fields — bot bounces incomplete filings with the exact missing list, no human triage spent on blanks):

| Field | Format | Why load-bearing |
|-------|--------|------------------|
| Persona + story | `P1/P2/P3/P4` + one-sentence story ("as P1 I want ... so that ...") | Unstoried asks can't map to §11 acceptance; unmapped asks drift to backlog mush |
| Problem evidence | link (compat row §15, exit quote §23, meter sheet ch.10 §8, or fresh repro steps + build ID) | §25 Definition-of-Ready requires evidence before discussion — intake enforces it at the door |
| Proposed behavior | ≤5-line behavior delta + affected FR/NFR id or `NEW` | Feeds §20 TRACEABILITY linkage and §17 classing (CLARIFICATION/EXTENSION/REDUCTION/PIVOT) |
| Workaround today | what the user does now + minutes-per-week cost | Prioritization input (§30 synthesis churn ranking consumes this field directly) |
| Scope guess | S/M/L per §25 sizing + kill condition proposal | Forces the asker to price honesty; kill conditions executed per §25, not extended twice |

Triage SLA (clock starts at filing timestamp, bot stamps every transition; missed SLA is a process P1 filed by whoever notices — §27 calendar discipline extended to the queue):

| Class | ACK (human hello + class guess) | TRIAGE (disposition + owner + date) | Notes |
|-------|-------------------------------|-------------------------------------|-------|
| Crash/data-loss/safety-adjacent | ≤1 business day | ≤3 business days (blocker-ladder §21 if DoD-linked) | Safety rows (telephony/emergency/OTA-rollback/security) jump to §21 daily review immediately |
| Feature within DoD spirit (EXTENSION candidate) | ≤2 business days | ≤7 business days with §17 class + gate-impact note | Gate-impact note names DoD rows moved + release train, or triage is incomplete |
| Non-goal-shaped (matches §4 list) | ≤2 business days (auto-close text below, human-signed) | same touch (no second round) | Re-open allowed only with new evidence (fresh compat data, carrier change, blob drop — "I really want it" reopens nothing) |
| Vague / incomplete | bot bounce ≤4h (missing-field list) | 14-day staleness close after bounce (warning at day 10) | Stale-close text links the template + one worked-example good request; no shame, just hygiene |
| PIVOT-shaped (reverses §4 or §12) | ≤2 business days (acknowledge + freeze) | ≤14 days with Arch review scheduled (§17 PIVOT path opened as tracking ADR) | Pivots are rare enough that each gets a retrospective (§17) — intake never slow-walks them into silence |

Non-goal auto-close text (verbatim, human name appended — bot posts, human owns; copy-paste drift rejected in review like §22 marketing drift):

> Thanks for requesting `<one-line paraphrase>`. This is on our explicit v1 non-goals list (ch.01 §4: `<GMS / Integrity-bypass / L1 / guaranteed-VoLTE-on-all-carriers / x86-tablet-watch / pKVM-dual-boot / own-store — delete-as-applicable>`), so we are auto-closing as `DECLINE-non-goal` with the reasoning public. What this means: no engineer is assigned, it is not on `reqs/BACKLOG.md` (§25 cap protects focus), and +1 comments do not reopen it. What reopens it: new evidence linked here (e.g., blob drop, carrier certification path, lawful compat change) — at which point it re-enters as a §17 PIVOT with brainstorm + threat-model pass, not a quiet flip. Honest alternatives today: `<compat-matrix row / F-Droid-Flatpak-apt path / blessed-carrier note §13 — concrete, not "soon">`. Closed by `<name>` on `<date>`, non-goal citation verified. — HALIDE triage

Duplicate and near-duplicate rule: first-filed canonical stays open; later dupes close as `DUPE-of #<id>` with the asker's evidencefields merged into the canonical (evidence merged, not discarded — dupe votes without evidence add heat, not light; heat counted separately as `+1-count` for §30 synthesis, never as new backlog items). Backlog promotion (§25 cap of 30 enforced at triage, not later): ACCEPT means the item displaces or waits — triager names the displaced PARKED item or the queue position (`BACKLOG-#<n>`), never "accepted to the void." Every ACCEPT carries persona+story link (§11), size (S/M/L), kill condition, and measurement plan pointer (§16 ruler + reserved ch.10 test IDs) — Definition-of-Ready checked at intake, completed at backlog grooming (§25 cadence).

Metrics (published monthly in `reqs/INTAKE-<YYYY-MM>.md`, consumed by §30 synthesis): filings by class, ACK-SLA hit %, triage-SLA hit %, median days-to-disposition, non-goal share (rising share = positioning §22 unclear, fix messaging not triage speed), dupe rate, backlog conversion rate, oldest-undispositioned age (any item >30 days undispositioned escalates to Product + Arch with written reason — same anti-drift rule as §27 reschedule-twice). Verification: bot SLA report green + spot-audit 10 closed issues/quarter (template completeness, non-goal text verbatim, §17 class correct, BACKLOG linkage present); audit failures filed as triage bugs with owner + date, not observations.

## 33. Release naming and image retention UX (one string everywhere, parsed by machines and read by humans)

Canonical version string (restates §13 with parsing teeth): `halide-v<major>.<minor>.<patch>+<sku>[-<channel>][.<buildmeta>]` where `major` = breaking OTA/partition change, `minor` = monthly train, `patch` = hotfix, `sku` = blessed-variant id (e.g., `refA-eu-6-128`, never bare `refA` — §12 variant rule means the SKU suffix pins storage/RAM/region), `channel` ∈ {`dev`,`beta`,`stable`} (default `stable` omitted in display, present in API), `buildmeta` = `<YYYYMMDD>.<git-short>` (traceability, never compared for precedence). Regex (single source of truth in `scripts/halide-version.py`, consumed by OTA matcher, Settings About, and release-notes linter — three parsers is how "same version, different behavior" is born):

```
^halide-v(?P<major>0|[1-9]\d*)\.(?P<minor>0|[1-9]\d*)\.(?P<patch>0|[1-9]\d*)\+(?P<sku>[a-z0-9]+(-[a-z0-9]+)*)(-(?P<channel>dev|beta|stable))?(\.(?P<buildmeta>\d{8}\.[0-9a-f]{7,12}))?$
```

Parsing and comparison rules (implemented once, tested by `tests/test_version.py` with 40 vectors including the traps): numeric tuple compare on (major, minor, patch) only — channel orders `dev < beta < stable` for display sorting, never for OTA eligibility (OTA eligibility additionally requires same-`sku` prefix + AVB rollback-index monotonicity ch.08 — a higher tuple with a lower rollback index refuses with the exact index named, ch.03 §18 size-guard pattern extended to versions); `buildmeta` ignored for precedence, required for bug reports (reports without buildmeta route to "re-capture via Settings → About → Copy" per support-log-script, not to engineering); SKU mismatch never "upgrades" (flashing `+refB` payload on `refA` hardware is refused pre-download with the §12-variant explanation, not post-flash with a brick); leading zeros rejected (`v1.03` fails lint — string-sort lies start here); case normalized lower before match (fingerprint-vs-string mismatches filed as tooling P1, §20 orphan-test rule applies to version vectors: every parsing rule has a test ID).

Settings → About fields (single screen, no "tap 5 times for the real version" — every row has Copy on long-press, values refresh without reboot after OTA staged/switch):

| Row | Source of truth | Example | Update trigger |
|-----|-----------------|---------|----------------|
| HALIDE version | `/etc/halide-release:HALIDE_VERSION` (written at image build, signed in SBOM ch.09 §11) | `halide-v1.4.2+refA-eu-6-128 stable` | image flash / slot switch (re-read on Settings open, never cached across boot) |
| Build date + commit | `HALIDE_BUILD_ID=<YYYYMMDD>.<short>` + manifest pin (ch.09 §1 `verify` link) | `2026-08-14 · a3f9c21` | same as above |
| Android security patch | container `ro.build.version.security_patch` via prop-bridge (ch.05 §9) | `2026-08-05` | container start (mismatch vs host noted inline, never silently older) |
| Kernel + GKI | `uname -r` + GKI tag (`/proc/version` + ch.03 ledger ref) | `6.6.48-halide-gki #1` | boot (slot-specific — About shows running slot's kernel, standby slot's in the retention card below) |
| Slot (A/B) + rollback | `update_engine_client --status` / `bootctl` equivalent (ch.09) | `Slot B · running · rollback: available (v1.4.1)` | OTA stage/apply/switch events (poll 5s while update screen open) |
| Carrier + modem FW | `mmcli -m` profile id + modem FW rev (ch.07 §11 matrix row link) | `Carrier FIN-Elisa · FW MPSS.AT.4.3.c2` | SIM/modem state change (UNTESTED-bold rendering per ch.07 §11 lint — same font as §12 variant UNTESTED) |
| Licenses / SBOM | SBOM artifact hash + `NOTICE.html` (§8 attributions) | `SBOM sha256:9f3a… · Licenses →` | per release (tap opens offline copy — About works in airplane mode, verified in test) |

Image retention UX (A/B slots + history, not infinite snapshots — storage §7 honesty applies to our own UI): running slot + one standby slot (rollback target while `rollback: available`, else standby shows staged version + Apply/Reboot CTA); history card lists last 3 applied versions (tuple + buildmeta + date + changelog link via ch.09 §14 template excerpt — "what changed" one tap away, not a forum hunt); retention bar shows `system/reserved/userdata` split with the 8GB-compressed-cap lineage (§7 audit link) so "update needs X MB, free Y MB by …" is a number, not a shrug; failed-boot auto-rollback surfaces a non-dismissible-until-read banner ("Update vX.Y failed to boot, rolled back to vX.Z — report + logs" with one-tap log export per recovery runbook ch.01 §6 FR-07); data-preserved line cites the A→B→A evidence (§5 DoD row) with build IDs. Copy-format contract (support-log-script consumes this verbatim): long-press Copy emits `HALIDE=<ver> BUILD=<buildmeta> SKU=<sku> SLOT=<A|B> KERNEL=<rel> SPL=<date> MODEM=<fw> CARRIER=<mcc-mnc|UNTESTED>` single line plus `manifest=<hash> sbom=<hash>` second line — pasted-without-edit in bug reports (reports with hand-retyped versions bounce to re-capture; transcription lies defeated by construction). Retention edge rules: factory-reset preserves the standby rollback image (reset wipes userdata, never the fallback slot — stranded-brick guard §13 EOL spirit); storage-low blocks staging with the exact MB shortfall + one-tap `halide-clean` (cache/old-log purge list, never silent deletion); channel downgrade (`stable`→`beta` on same tuple) requires explicit opt-in toggle with data-loss warning + backup nudge (ch.05 export path). Verification: `tests/test_version.py` 40/40 + screenshot-diff of About on both slots (CI golden set per §16 localization method — untranslated About strings fail the same diff) + on-device script `halide-about --json` output schema-validated against `schema/about.json` (field missing = test fail, not "UI polish later") + OTA-stage drill asserting standby-slot About row updates pre-reboot (stale About across slot switch is a P1 — version lies rot trust faster than late dates, §18 slip-rule spirit).

## Verification for this chapter

- [ ] Stakeholders sign DoD table verbatim (no "etc.").
- [ ] Non-goals posted publicly to deflect feature requests.
- [ ] Personas mapped to test plan IDs in ch.10.
- [ ] `signoffs/<gate>.md` present with 5-role signatures on a named build ID (no "latest").
- [ ] `reqs/TRACEABILITY.csv` has zero orphan reqs; `req-trace-check` green on last 20 MRs.
- [ ] `bugs/LAUNCH-BLOCKERS.md` triaged within SLA; waivers (if any) carry expiry + unanimous safety sign.
- [ ] `releases/POSITIONING.md` + `releases/COST.md` published with measurement links; no superlative without data.

Next: `02-hardware-matrix.md`.
