# 09 — Build System, Image Factory, OTA & CI
**Budget: 60,000 chars · Phases: 0–3 · Owner: Release · Rule: reproducible or it didn't happen**

## 1. Repo & manifests (one pin to rule them all)

```
~/hybrid/
  manifests/  # MANIFEST (super-pin: kernel SHA + AOSP rXX + Debian snapshot + Mesa + keys id)
  kernel/ aosp/ debian/ overlays/halide/  # overlays = our code (bridges, composer, units, configs)
  images/ keys/ logs/ sbom/
```

Release = tag `halide-vX.Y.Z+<sku>` + super-manifest SHA + container digest. `halide-manifest freeze > MANIFEST.lock` records every SHA; `verify` re-resolves and fails on drift.

## 2. Build flow (host container, pinned digest)

```bash
# builder image digest pinned in ci/Dockerfile
docker run --rm -v ~/hybrid:/w halide-builder@sha256:<pin> /w/scripts/build-all.sh <sku> user
# scripts/build-all.sh stages:
#  1. kernel (Image.gz+modules+dtb) → 2. AOSP (super.img) → 3. Debian rootfs →
#  4. assemble (partition images + LXC rootfs) → 5. sign → 6. SBOM+NOTICE → 7. ota payload
```

Assemble: `super.img` (system/vendor/product), `boot.img`, `vendor_boot`, `vbmeta`, `dtbo`, `host.img` (Debian ext4/erofs), `userdata` (empty, encrypted on first boot). Sizes per SKU flash map in `images/<sku>/flashmap.json` (never guess at flash time).

Two-builder reproducibility test: same digest + same MANIFEST → `sha256sum super.img system.img` identical modulo documented signature/timestamp fields (list fields explicitly; everything else must match).

## 3. Signing (offline, audited)

Private keys never on builders. Flow: builder → unsigned artifacts + `hashes.txt` → air-gapped signer (USB) → signatures + `sigstore`-style transparency log entry → publish. Dev/test keys clearly named (`testkey` — devices show orange state; grep CI to prevent testkey release: `if avbtool info | grep testkey → fail`).

## 4. A/B OTA

`update_engine`-compatible payload (`payload.bin` + `payload_properties.txt` + `metadata.json` with changelog + size + required battery). Device logic: download → verify → write inactive slot → `bootctl mark-boot-successful` handling → reboot → health-check (container boot_completed + radio registered ≤5 min) → commit slot, else rollback + report (`halide-ota-report` redacted).

Staged rollout: 1% → 10% → 50% → 100% with 48h bake + crash-rate/rollback-rate gates (rollback >2% halts rollout automatically). Delta + full payloads; resume supported.

## 5. Factory & recovery

Factory flash (wired): `fastboot flashall` script per SKU + GPT backup reminder + fuse/AVB lock step (explicit operator confirm). Recovery: minimal AOSP recovery with ADB sideload, `halide-log-collect`, factory reset (crypto-erase), slot switch. Recovery never mounts userdata decrypted without auth.

## 6. CI (per MR + nightly + release)

- Per-MR (VIRT): manifest verify, kernel defconfig build, sepolicy check, AppArmor compile, bridge fuzz 10 min, shellcheck, `wc -m` budget check (plan docs stay in window).
- Nightly (REF-A where hardware-lab attached, else QEMU): full image build + boot-qemu smoke (`boot_completed` + Phosh screenshot diff).
- Release: two-builder repro, VTS/CTS subset, signing ceremony, staged OTA publish, advisory draft.

Artifacts per build: images + `MANIFEST.lock` + `SBOM.spdx.json` + `THIRD-PARTY` + `avbtool info` dumps + `cvecheck` output. Retain 180 days.

## 7. Builder image & hermeticity (normative)

`ci/Dockerfile` pins `debian:bookworm-<date>-slim@sha256:<digest>` + exact package versions (`apt list --installed` frozen via `ci/packages.lock`); toolchain (clang-r498229+, `mkbootimg`, `avbtool`, `lxc`, `mmdebstrap`) versioned the same way. No network at build time except an allowlisted snapshot proxy (AOSP fetch happens in a separate `fetch` stage whose output hash is recorded — builds consume the frozen fetch, never live googlesource). `halide-manifest verify` fails on: floating revisions, missing SHAs, digest mismatch, snapshot older than policy (90 days → warning, 180 → fail).

`scripts/build-all.sh <sku> {user,userdebug,eng}` stages with per-stage timing + artifact SHAs to `logs/build-<sku>-<ts>.json` (build observability: stage durations regressed automatically — a 2× slowdown pages infra, not a shrug). `ccache`/`sccache` allowed with `CCACHE_HASHDIR` + config hash recorded (cache poisoning discipline: cache key includes MANIFEST.lock SHA; different manifest = cold cache, never mixed).

## 8. Assembly & partition tables (exact, per SKU)

`images/<sku>/assemble.sh` consumes: kernel `Image.gz+modules+dtb/dtbo`, AOSP `system/vendor/product` dirs, Debian rootfs tar, firmware list (`vendor/<sku>/` per ch.02 §4). Outputs with sizes validated against `flashmap.json` BEFORE signing (oversize = fail with byte counts, never truncate silently): `boot.img` (64M), `vendor_boot` (64M), `dtbo` (8M), `vbmeta` (8M), `super` (device-specific, e.g., 9G SDM845), `host.img` (Debian erofs/ext4, 3.5G), plus `misc` slot metadata init.

erofs for read-only partitions (reproducible, compressed, verity-friendly) with `mkfs.erofs -C4096 -T$SOURCE_DATE_EPOCH`; ext4 only for userdata template (empty, `mke2fs -O encrypt`). `super` built with `lpmake` + `device-size` from flashmap; `avbtool add_hashtree_footer` per logical partition with `--do_not_generate_fec` only where flash wear analysis justifies (document per SKU).

`halide-assemble-lxc` (ch.04 §15): unsquashed dev rootfs (with adb/strace/perfetto) vs erofs release rootfs (no adb, `ro.adb.secure=1` enforced + CI grep). `/etc/halide-release` + container `build.prop halide.version` major-minor must match or first-boot refuses with banner (mixed-version bricks prevented by construction).

## 9. OTA payload engineering & rollback safety

Payload: full + delta (`update_engine` `payload.bin` + `payload_properties.txt` + `metadata.json`: version from/to, size, required battery ≥30% + charger-or-override, changelog URL, `deadline` for security updates). Device flow: download (resume, hash-chunks) → verify (key + rollback-index > current) → write inactive slot → `bootctl set-active-boot-slot` staged → reboot → health gate (systemd running + `sys.boot_completed=1` + MM registered + 1 SMS loopback self-test ≤5 min) → `mark-boot-successful`; any gate miss → auto-rollback + `halide-ota-report` (redacted: versions, gate-times, failure stage — no IMSI).

Rollback-rate telemetry (opt-in, redacted): rollout halts automatically at >2% rollback (ch.04 gate referenced); on-halt runbook: freeze rollout, pull 5 redacted reports, bisect against MANIFEST delta, hotfix or re-key. Delta generation: `bsdiff`/`puffdiff` on erofs images with 100M cap (bigger → full payload; record sizes in release notes so users on metered links can plan).

`sideload` path (recovery, no network): same payload via ADB with identical verify+health gates (sideload doesn't skip safety).

## 10. Factory flash & technician runbook

`factory/<sku>/flashall.sh`: (1) GPT backup to operator PC (`--backup-first`, refuse without `--i-have-backup` or fresh `--take-backup-now`), (2) flash all partitions per flashmap with per-partition verify (`fastboot getvar` + `avbtool info_image`), (3) `fastboot -w` ONLY with typed SKU confirm, (4) AVB lock step (`fastboot flashing lock` — explicit operator `YES`, with unlock-warning printout), (5) first-boot smoke (boot_completed + signal bars photo in traveler). Time budget: ≤12 min wired flash; runbook tested by a non-engineer quarterly (fresh-eyes test — if they brick it, the runbook is wrong, not the tech).

RMA/unbrick: EDL package per SKU (`hw/<sku>/edl.md` referenced) with signed loader hashes; EDL use logged (who/when/why) — unbrick without log = process fail.

## 11. CI pipelines (concrete jobs, not vibes)

Per-MR (~25 min VIRT): `manifest-verify` → `kernel-defconfig` (defconfig+dtbs, no full Image) → `sepolicy-neverallow` → `apparmor-compile` → `seccomp-validate` → `bridge-contract-tests` → `fuzz-smoke-10min` → `shellcheck+shfmt` → `socket-audit` (SOCKETS.md vs code) → `plan-budget-check` (`wc -m` window). Any red = no merge, no exceptions for "trivial" (trivial MRs cause trivial bricks).

Nightly (~3h, QEMU + REF-A if lab attached): full `build-all.sh` → boot QEMU (systemd + boot_completed + drawer screenshot diff vs golden, ≤2% pixels) → `permission-sync.sh` ×20 → VPN-leak test → power-smoke (suspend 5 cycles virtualized) → publish nightly with `DONOTUSE-daily` watermark + auto-expiry (nightlies refuse to boot after 30 days — prevents fossil nightlies becoming daily drivers).

Release (~2 days + ceremony): two-builder repro (hash compare modulo listed fields) → hardware smoke on both REF units → CTS/VTS subset (ch.10) → signing ceremony (§3) → staged OTA (1→10→50→100%) with bake gates → advisory draft → transparency publish. Release branch frozen at RC1; only cherry-picks with QA sign + Arch sign land after.

Artifacts (180-day retention): images + `MANIFEST.lock` + `SBOM.spdx.json` (generated by `scripts/sbom.sh`: kernel+AOSP+Debian package lists + firmware SHAs) + `THIRD-PARTY` + `NOTICE` + `avbtool info` dumps + `cvecheck`/`debsecan` outputs + build-timing JSON. SBOM diff vs previous release is a release-notes section (new blobs are news, not footnotes).

## 12. Nightly expiry & fossil prevention (nightlies must die on schedule)

Nightly images embed `halide.nightly_expiry=<date+30d>` (ro property + host file); `halide-nightly-watch` (daily timer) warns at 7-days-left (persistent card with "flash release or newer nightly") and refuses Android-container start past expiry (host still boots — data recoverable, radio stack halted with explanation, never a silent dead phone). Rationale documented in-image (link to this section): nightlies lack staged-rollout safety + signing-ceremony provenance (ch.09 §§3–4) — expiry is load-bearing safety, not annoyance. Dogfood fleet runs release-candidates, not nightlies (fleet rule — RCs have ceremony + reports; nightlies are for lab + brave individuals). Expiry drill: quarterly boot of a 31-day-old nightly in lab → container refusal + host-alive + data-export works (runbook-recovery §3 path usable from expired nightly — exit always open).

## 13. Digest pinning & builder-compromise response (supply chain honesty)

Every external input pinned by digest, not tag: builder base image, AOSP remote (manifest SHA), Debian snapshot stamp, Mesa/firmware SHAs, toolchain tarballs (clang + `BUILD_RBE`-off record, ch.03 §11). `halide-manifest verify` checks all pins pre-build (unpinned input = fail with the input named). Builder-compromise runbook (rehearsed annually as tabletop, not read during incident): (1) freeze CI + revoke builder deploy keys, (2) rebuild last-release images on fresh builders from MANIFEST.lock → compare hashes (match = builders clean post-rotation; mismatch = investigate artifacts, hold OTA), (3) rotate all builder-facing credentials + transparency-log entry, (4) public note if any shipped image is suspect (ch.08 §8 advisory template reused). Two-builder repro (ch.09 §2) doubles as compromise detection — unexplained hash divergence pages Security, not just Release.

## 14. Release-notes template (every release, same sections — comparability is the feature)

```
halide-vX.Y.Z+<sku> (<date>) — <one-line theme: "radio stability">
GATES: dogfood <pass/fail + P0/P1 counts> · CTS/VTS <x/y + quarantined z> · power <link sheet>
IMAGES: <hashes + sizes> · MANIFEST.lock <sha> · builder digests <both>
SBOM DIFF: +<new> ~<upgraded> -<removed> (new blobs named, ch.09 §11)
CARRIERS: <blessed list + emergency statuses + perf deltas>
COMPAT: <TOP-100 hit-rate + notable moves>
KNOWN ISSUES: <each with bug + workaround-or-none + target>
CVE DISPOSITIONS: <patched/not-affected/mitigated per ch.08 §11>
UPGRADE: <full/delta sizes + battery requirement + staged % + deadline if any>
```

Known-issues honesty rule: fluffy "minor bugs" entries rejected in review — each issue names the failing behavior + who it hurts (P1/P2/P3) + workaround-or-"none, tracked <bug>". Notes published before rollout passes 10% (early adopters read; late majority benefits).

## 15. Signing ceremony script (offline machine, two custodians — ch.08 §8 policy executed)

```bash
# ON BUILDER (online): produce unsigned set
scripts/build-all.sh $SKU user --no-sign
sha256sum out/$SKU/{boot,vendor_boot,vbmeta,super,host}.img payload.zip > hashes.txt
# SNEAKERNET hashes.txt + images to offline signer (USB, scanned, single-purpose stick labeled SIGN-X)
# ON SIGNER (offline, Custodian-A + Custodian-B present, log started):
avbtool verify_image --image boot.img --key keys/release_pub.key          # confirm unsigned-expected state
sign-all.sh --key /mnt/hsm/release.key --rollback $BUILD_NUM --in ./ --out ./signed/  # signs + writes signatures.json
cat signatures.json   # both custodians read key-id + rollback aloud, compare to release plan (verbal check defeats wrong-key-file)
sha256sum signed/* | tee signed/SHA256.signed.txt
# SNEAKERNET back; builder publishes signed/ + signatures.json + transparency entry (ch.08 §8)
```

Ceremony log (`keys/ceremonies/<date>-<ver>.md`): attendees, key-id fingerprints, rollback values, hashes before/after, anomalies-or-"none" (an "anomalies: none" line is required — missing line = incomplete ceremony = release blocked). Wrong-key drill annually: custodian deliberately presents previous-key file → ceremony must halt at verbal check (drill logged; halt-failure = P0 process bug).

## 16. Factory-line tooling (technician-proof, ch.09 §10 runbook executed by software)

`factory/flash-station/` (runs on a Debian laptop, one window, big buttons): auto-detects unit (`fastboot devices` → SKU match vs flashmap, mismatch = big-red-halt, never flash REF-A images into REF-B), backup-first gate (`--take-backup-now` writes `persist/efs/modemst` + GPT to operator PC with SHA + free-space check before any write), per-partition progress bars with verify-after-write (`avbtool info_image` re-read + hash compare — write-without-verify is how silent corruption ships), AVB-lock as separate explicit step (checkbox + typed `LOCK` + warning text, never bundled into "flash all"), first-boot smoke trigger (reboot → poll `boot_completed` ≤5 min → PASS sticker data: unit label + version + timestamp printed for the traveler). Station logs every action to `factory/logs/<unit>-<date>.log` (append-only; log upload at shift end — unlogged flashes don't count toward the ≤12-min metric because unmeasured work isn't managed).

## 17. Artifact transparency (every shipped byte traceable — ch.08 §8 log made concrete)

`halide-transparency` repo layout per release (`transparency/<ver>/`): `MANIFEST.lock` SHA, `hashes.txt` (builder unsigned set), `SHA256.signed.txt` (signer output), `signatures.json` (key-ids + rollback + timestamps), `SBOM.spdx.json` SHA + diff summary, `avbtool info` dumps, ceremony log id (keys/ceremonies link). Append-only enforced branch-side (force-push disabled + two-person rule on history rewrite — rewrite attempts alert). Verification any user can run (release page documents exactly): fetch transparency dir → `sha256sum -c` on downloaded images → `avbtool verify_image --key <pub from keys/>` → compare rollback vs published notes (ch.09 §14 template carries the values). Third-party mirror support: mirrors serve images + pointer file to canonical transparency commit (mirrored bytes verifiable without trusting the mirror — stated on the mirrors page so mirror operators aren't trust bottlenecks).

## 18. Build-failure triage runbook (red builds get a doctor, not a shrug)

Severity + SLA: `BUILD-BLOCKED` (no nightly in 24h or release branch red) = P0, triage ≤4h; `MR-RED` (single MR job fail) = owner fixes ≤24h or reverts; `FLAKY-INFRA` (exit-2 class, ch.10 §7) = lab-infra issue, MTTR recorded. On-call: Release owner primary, infra secondary (roster in `program/CALENDAR.md` ch.11 §15 — missing roster entry = bot files it).

Triage ladder (same order every time — discipline beats brilliance):
1. Classify in 5 min: read `logs/build-<sku>-<ts>.json` stage-timing + SHA table (§7). Failing stage named + stage-duration delta vs trailing-5-green median. If duration 2×+ with same manifest → infra-suspect (disk/cache/runner), not code-suspect. If fail immediate at `manifest-verify` → pin/digest issue (§13), never rebuild blindly.
2. Isolate: re-run the single failed stage container-locally with identical digest + MANIFEST.lock (`scripts/repro-stage.sh <stage> <log-id>` — recorded command, not tribal knowledge). Pass-locally + fail-CI = runner/cache divergence (purge `ccache` keyed by MANIFEST SHA per §7, re-run). Fail-locally = real breakage, bisect from MANIFEST delta (AOSP rev / kernel fragment / overlay file list in the log header — the header exists so bisection starts in minutes).
3. Common-failure table:

| Signature | Likely cause | Fix | Prevention |
|---|---|---|---|
| `lpmake: device-size exceeded` | flashmap drift / erofs growth | per-partition byte counts (§8), grow `super` only via flashmap change + ADR | CI oversize-fail already gates; add growth-trend alert at 90% |
| `avbtool: rollback index` | BUILD_NUM not bumped / wrong key file | verify rollback vs plan + verbal-check discipline (§15) | ceremony log `anomalies` line; wrong-key drill annually |
| `sepolicy neverallow` | new HAL/bridge permission | fix policy with bug-ID comment (ch.08 §4), never blanket allow | per-MR neverallow job (§11) stays blocking |
| `apparmor compile` | profile/sockets drift | regen from SOCKETS.md (§10 socket-audit job) | socket-audit blocks merge |
| `fuzz-smoke crash` | parser regression | P0 + regression seed committed (ch.08 §10) | 10-min smoke stays blocking |
| `testkey in release` | wrong build variant | halt, rebuild `user` (§8 variant discipline) | CI grep gate (§3) + manual avbtool attach |
| `fetch hash mismatch` | upstream moved under us | freeze-fetch re-pin (§13), never `--no-verify-fetch` | snapshot-proxy + frozen fetch |
| `ccache poisoning` (unexplained object diff) | mixed-manifest cache hit | cold rebuild with manifest-keyed cache (§7) | cache-key includes MANIFEST.lock SHA |

4. Communicate: `BUILD-BLOCKED` gets a single tracking issue (symptom, failing stage, log link, owner, ETA update every 4h). No side-thread debugging in chat (chat diagnoses, issue records — the issue is the record release review reads).
5. Close-out: root cause + fix commit + regression test or gate added (a triage that adds no prevention is incomplete — §18 triages feed §11 pipeline deltas). Two-builder repro re-run after any builder/infra fix (hash compare per §2 confirms the fix didn't fork the fleet).

## 19. Artifact mirror operations (mirrors are untrusted by design — verify anyway)

Mirror topology: canonical (`halide-transparency` + release page, ch.09 §17) + N community mirrors (listed on mirrors page with operator + region + sync lag). Mirrors serve images + pointer file to canonical transparency commit (never authoritative metadata — §17 stated so operators aren't trust bottlenecks).

Operator requirements (lightweight, committed): sync from canonical only (rsync/http with SHA check against `SHA256.signed.txt` before serving — serve-after-verify, not serve-and-hope), expose `/healthz` (artifact SHAs + transparency-commit id + sync timestamp; our monitor polls hourly), retention ≥2 latest releases per SKU, no recompression/repackaging (byte-identical or delist — helpful "optimizations" break `sha256sum -c` user verification).

Monitoring (our side): hourly poll of every mirror healthz (lag >24h = warn operator; >72h = delist + note on mirrors page); weekly random-byte audit (fetch 3 images from random mirror, `sha256sum -c` vs canonical — mismatch = immediate delist + §13-style incident (treat like builder-compromise signal: freeze rollout past current %, investigate canonical vs mirror provenance) + advisory if any user fetched the bad bytes (download logs from mirror operator requested within 24h). User guidance on release page (3 lines, exact): fetch → `sha256sum -c` → `avbtool verify_image --key <pub>` → compare rollback (ch.09 §17 procedure — repeated here by reference so mirror users get the same ritual, not a weaker one).

Mirror onboarding/offboarding: onboarding = operator PR (endpoint, region, contact, retention pledge) + 2 successful weekly audits before listing; offboarding = delist PR + transparency note (no silent removals — users with bookmarks deserve the redirect). Annual mirror review (ch.11 §15 calendar adjacent): audit stats, lag histogram, operator responsiveness (mirrors without 2 green audits/quarter are delisted — dead mirrors are phishing real estate).

## 20. Staged-rollout monitoring dashboards (the 1%→10%→50%→100% cockpit)

Rollout stages per §4 (1% → 10% → 50% → 100%, 48h bake each) with automatic halt at >2% rollback. Dashboard (`release/rollout-<ver>.md` + live telemetry view, same numbers both places — dashboard-vs-notes drift is a release-blocker):

Panels (all redacted per §4 report rules — versions, gate-times, failure stage; no IMSI):
1. Rollback-rate gauge (per stage, trailing 24h): green <0.5%, amber 0.5–2%, red >2% (auto-halt + page on-call per §18 severity). Rollback reasons split (health-gate miss: container boot / radio-register / SMS-loopback per §9 device flow — the split tells you which subsystem the OTA broke).
2. Health-gate latency histograms: `boot_completed` time, MM-registered time, SMS-loopback time (p50/p95 per stage; p95 drift >20% vs previous release = amber investigation even under rollback threshold — slow is the prequel to failed).
3. Crash-rate delta: dogfood-crash baseline (ch.10 §10 taxonomy P0/P1 per 1,000 device-days) vs rollout-stage crash rate (same taxonomy — comparable or the comparison is theater).
4. Download/verify funnel: started → verified → slot-written → rebooted → committed (drop-off at verify = key/rollback-index issue §15; at slot-write = storage/partition issue §8; at commit = health-gate issue §9 — funnel location is the first diagnosis).
5. Fleet mix: SKU split + from-version split + carrier split (a 1% stage that's all one SKU isn't a bake, it's a demo — stage-promotion requires minimum mix: ≥2 SKUs + ≥3 carriers represented, else extend bake).

Stage-promotion checklist (human sign + auto-gates both required): auto (rollback <2%, no red panel, bake clock elapsed) + human (on-call + QA confirm in rollout issue, 48h watch roster named per ch.10 §16 sign-off form — the named humans from sign-off are the eyes on 1%/10%). Halt runbook (on red): freeze (stop promoting, keep serving current stage — already-updated devices stay, no mass-rollback unless §13 compromise), pull 5 redacted reports (§4 `halide-ota-report`), bisect MANIFEST delta, decide hotfix-lane (§21) vs full-train fix within 24h (decision logged with owner + clock — halted rollouts without a clock become abandoned rollouts).

## 21. Hotfix lane ops with 24h clock drills (small, fast, safe — pick all three)

Entry criteria (any one): security `PATCH-NOW` (ch.08 §15 ≤7-day bin), rollout-halt fix (§20), dogfood-P0 with fleet-wide impact (ch.10 §10). Non-criteria (stays on monthly train): features, perf tuning, non-exploitable hardening (hotfix lane scope discipline — every out-of-scope cherry-pick doubles review load and halves safety).

Hotfix branch mechanics: cut from the exact shipped tag (`halide-vX.Y.Z+<sku>`, MANIFEST.lock SHA pinned — hotfix never floats forward to main mid-lane), cherry-picks only (each with QA sign + Arch sign per §11 release-branch rule; pick size ≤300 lines preferred — bigger picks ride the train, not the lane), full §11 release-job subset on the hotfix candidate (two-builder spot-check on affected images + hardware smoke on both REFs + affected-suite CTS slice + `avbtool` + testkey-grep — the lane skips nothing safety-critical, it skips breadth).

24h clock (binding): T+0 decision logged (hotfix vs train, owner, CVE/bug id) → T+4h candidate built + CI subset green → T+8h hardware smoke + sign-off deltas (ch.10 §16 form mini-version: gates-affected evidence only, exceptions explicit) → T+12h signing ceremony expedited (both custodians, same verbal checks §15 — expedited never means abbreviated) → T+16h staged restart at 1% (fresh bake clock, same §20 dashboard) → T+24h go/no-go for 10% (rollback-rate + crash-delta reviewed). Clock overruns escalate to Arch at T+12h (help-or-descope decision, not silent slip).

Drills (quarterly, game-day): synthetic P0 filed against staging (planted bridge-parser crash with fuzz seed, or staged rollback-rate breach on internal fleet) → team runs the full lane on the clock (decision → branch → build → smoke → ceremony-with-test-keys → staged-internal-OTA → halt-or-promote). Drill scored: clock met? ceremony checks skipped-under-pressure? (any skip = drill fail + P0 process bug per §15 wrong-key doctrine) dashboard used or eyeballed? Report in `release/hotfix-drill-<date>.md` (times per milestone + what lied + 1 prevention item). Two consecutive missed clocks = lane-capacity review (owner Release, ch.11 §11 build-health metrics carry the trend).

## 22. Release-branch freeze, cherry-pick review & RC respin rules (frozen means frozen)

Freeze point: RC1 cut from develop at the §11 release-job green (branch `release/vX.Y.Z`, MANIFEST.lock pinned + recorded in `release/rc-<ver>.md`). From freeze to rollout-100%, the branch accepts only cherry-picks — each pick needs: bug/CVE id, QA sign (affected-gate evidence re-run on the RC, not on develop — develop-green is not RC-green), Arch sign for cross-cutting (same 2-sign rule as repo-layout hotfix path), size note (≤300 lines preferred; bigger picks require a full release-job re-run, not the subset — the subset covers affected images, the full run covers interactions).

Respin rules (RCn → RCn+1): any pick touching kernel/boot/vbmeta/OTA-verify resets the bake clock (dogfood delta-soak 48h minimum on the respun RC + §20 stage-1 bake restarts — slot/boot changes invalidate prior bake, no exceptions); picks touching only apps/composer/assets keep the clock but re-run the affected screenshot/perf gates (ch.10 §§9/12 goldens re-compared). Respin budget: ≤3 RCs per release (4th respin triggers Arch review: split the release (ship blockers now, defer rest) or slip the date — endless respins are how dates die quietly). Each RC gets its own transparency dir (§17) + SBOM diff vs RCn-1 (ch.09 §11 diff discipline at RC granularity — reviewers see exactly what the respin changed).

Thaw: rollout-100% + 7-day quiet (rollback-rate green + no P0) merges the release branch back to develop (merge commit, not rebase — history shows what shipped), tags `halide-vX.Y.Z+<sku>` signed in ceremony (§15), branch locked read-only. Emergency post-thaw fix rides the hotfix lane (§21), never a branch unlock (unlocked release branches accumulate "just one more" until they are develop with a fancier name).

## 23. CI runner provisioning & hardening (ephemeral, attested, least-privilege)

Runner classes (three, never mixed): `builder` (runs `build-all.sh`, heaviest, no lab USB), `virt-ci` (per-MR fast jobs, QEMU-only), `lab-runner` (drives REF units via USB/UART, ch.10 §7 harness). All three boot from the same pinned runner image doctrine as ch.10 §22 (`lab/runner-image.md`: Debian stable digest + `ci/packages.lock`-style package freeze + kernel version recorded). No snowflake runners: any runner that cannot be re-imaged from definition in ≤30 min is decommissioned, not debugged.

Provisioning (`infra/runners/provision.sh --class <builder|virt-ci|lab-runner> --id <rNN>`): (1) netboot/netinstall from canonical image SHA (SHA verified pre-install, mismatch = abort + alert), (2) cloud-init/ansible applies `infra/runners/<class>.yaml` (users, mounts, firewall, cron guards), (3) enrolls in inventory `infra/runners/inventory.csv` (id, class, MAC, TPM EK pub if present, image SHA, owner, date), (4) self-test (`infra/runners/selftest.sh`: disk ≥200G free, docker digest matches `ci/Dockerfile` pin, no `testkey` material present via `grep -r testkey keys/`, egress allowlist enforced). Only selftest-green runners join the pool (CI scheduler polls inventory health flag, never a static hostname list).

Hardening baseline (all classes): SSH with ed25519 only + `PasswordAuthentication no` + fail2ban; builder/virt-ci run builds as unprivileged `builder` uid with no sudo (docker-in-docker banned — outer docker only, `--read-only` rootfs + tmpfs workdirs where supported); secrets never on disk (OIDC short-lived tokens ≤1h for artifact upload, transparency push, mirror healthz; deploy keys scoped per-class: builders push unsigned artifacts only, never to `transparency/` protected branch); egress allowlist (snapshot proxy + package mirror + git remotes only — direct googlesource/debian-archive bypass fails closed and pages infra, per §7 frozen-fetch doctrine); full-disk encryption on lab-runners + builders with unattended-boot exemption documented (TPM-sealed key where hardware supports, else LUKS passphrase in sealed envelope per ch.08 §8 custodian model); automatic security updates for host packages weekly with runner-image rebuild monthly (host drift beyond 30 days = `STALE-RUNNER` label, scheduler drains it).

Lab-runner extras: USB device ACLs (`uaccess` + udev rules pinning each REF serial to `/dev/halide/<unit-label>` symlinks — `/dev/ttyUSB0` roulette banned), physical cable map photo committed per quarter (ch.10 §22 USB-port log made visual), no RF-chamber remote flash without Tier-0/1 (ch.10 §18), runner-local redaction enforced (`--redact` default in every `tests/*.sh`; raw `logcat`/`dmesg` with IMSI/serial never leaves the runner unredacted — upload job greps for `IMSI|IMEI|serialno` patterns and quarantines the artifact on hit).

Attestation & rotation: builder/virt-ci images rebuilt monthly + on any CVE-`PATCH-NOW` affecting the toolchain (ch.08 §15 clock applies to infra too); runner deploy keys + OIDC issuer trust rotated quarterly (`infra/runners/rotation-<date>.md` log: old fingerprint, new fingerprint, runners re-enrolled count); compromised-runner response reuses §13 builder-compromise ladder (freeze class → rebuild last-release on fresh runner → hash-compare via two-builder repro §2 → rotate credentials → transparency note if shipped bytes suspect). Annual runner game-day: deliberately mis-provision one staging runner (wrong digest + stale packages) → provision/selftest must reject it before it takes a job (reject-failure = P0 infra bug).

Capacity & scheduling: per-class floor (≥2 builders for two-builder repro parallelism, ≥2 virt-ci for MR burst, ≥1 lab-runner per 2 REF units); queue-depth alerts (MR wait >30 min pages Release secondary); nightly window 22:00–06:00 reserved for full builds (§11) with preemption rules shared with ch.10 §18 lab calendar (release week freezes Tier-2/3 lab-runner ad-hoc jobs). Runner metrics logged per job (`logs/runner-<id>-<ts>.json`: queue wait, stage times, disk before/after, cache-hit %) feeding ch.10 D1 build-health dashboard.

## 24. Build-cache poisoning defenses & key rotation (fast without trusting the past)

Cache inventory (each with distinct key + store + threat model, `ci/cache-inventory.md` is normative): (1) `ccache/sccache` object cache (builder-local + shared S3-equivalent bucket), (2) AOSP frozen-fetch tarball store (§7 fetch stage output), (3) Debian snapshot proxy cache (apt-cacher-ng with snapshot stamp), (4) container layer cache (builder image layers by digest). No other caches permitted (Gradle/Go-module caches only if a future component needs them, each added here with key schema before use — undocumented caches fail `manifest-verify`-adjacent `cache-audit.sh`).

Key schema (all keys include `MANIFEST.lock SHA` + builder-image digest + toolchain version string; never branch-name-only or timestamp-only): `ccache: <manifest-sha8>-<builder-digest12>-<clang-ver>`; `fetch: <manifest-sha>-<fetch-stage-hash>`; `debsnap: <snapshot-stamp>-<arch>`; `layers: <dockerfile-digest>`. Different manifest = cold cache by construction (§7 rule restated as key math — cache reuse across manifests is the poisoning vector this kills). Branch-scoped suffix (`-develop`, `-release/vX.Y.Z`, `-hotfix/`) prevents release builds warming from unreviewed develop objects; hotfix lane (§21) uses release-branch cache only, never develop (hotfix speed comes from small scope, not borrowed objects).

Poisoning detection (defense in depth, not key-hygiene alone): weekly `cache-bypass` canary build (one nightly per week runs with empty cache mounts, same MANIFEST → hash-compare vs cached build modulo §2 listed fields; divergence = `CACHE-SUSPECT` P0, cache quarantined, §18 triage table `ccache poisoning` row invoked); two-builder repro (§2) always runs with builders on *different* cache states (builder-A warm, builder-B cold after rotation — identical output from divergent caches proves hermeticity); `cache-audit.sh` per build records (key used, hit %, objects written, store SHAs) into `logs/build-<sku>-<ts>.json` header (§18 triage reads this first); fetch/debsnap stores are content-addressed (SHA-verified on read, §13 pin checks — a poisoned proxy serves bytes that fail verification, never bytes that build).

Rotation schedule: manifest-triggered (automatic — new MANIFEST.lock SHA = new key namespace, old namespace retained read-only 14 days for bisect builds then GC'd); time-triggered (even with stable manifest, `ccache` namespace rotates every 90 days, container layers every builder-image rebuild, fetch store every snapshot-policy window §7); emergency (any §13 compromise signal or canary divergence rotates all keys immediately + purges shared bucket writes for 24h while investigation runs — builds continue cold, slower but trusted). Rotation log (`ci/cache-rotations.md`: date, trigger, old/new key prefixes, GC'd bytes, canary result) reviewed in quarterly infra review alongside §23 runner game-day.

Operator rules (short, binding): never `--no-verify-fetch` or `CCACHE_SLOPPINESS=time_macros` to "fix" a red build (§18 table already bans the former; the latter is banned here — timestamp-sloppiness hides repro breaks); never share a cache bucket across trust zones (public-fork PR runners use an isolated bucket with no promotion path to release namespaces); cache-size caps enforced (ccache 50G/builder, fetch store 200G, GC oldest-namespaces-first with 7-day tombstone log so bisection can still name what was collected).

## 25. Release-branch gardening rules (frozen branches stay prunable)

Scope split with §22 (freeze/respin) and §11 (release pipeline): §22 governs *what may land* during freeze; this section governs *how the branch garden is kept* across the whole release lifecycle (cut → freeze → thaw → lock) so frozen branches never rot into second develops. Owner Release; gardening bot proposes, humans dispose (same doctrine as ch.10 §17 goldens — bot auto-merge of garden actions is banned).

Branch lifecycle states (`release/vX.Y.Z`, recorded in `release/rc-<ver>.md` header): `CUT` (branched at RC1 green, CI full-run scheduled) → `FROZEN` (only §22 cherry-picks) → `BAKING` (staged rollout 1%/10% per §26 autopilot, branch still frozen) → `THAWED` (100% + 7-day quiet per §22, merge-back to develop) → `LOCKED` (read-only, force-push disabled, two-person rewrite rule per §17). State transitions are bot-labeled + human-confirmed in the release issue (bot label without human confirm within 24h pages Release owner — silent state drift is how "frozen" branches accept features).

Gardening cadence (weekly 30-min during FROZEN/BAKING, owner Release + QA + Arch as needed): (1) cherry-pick queue review (each candidate: bug/CVE id, size note ≤300 lines per §22, QA-sign status, Arch-sign if cross-cutting; stale candidates >7 days without signs are dropped from the queue with a comment, not carried as hope), (2) CI health on the branch (full release-job subset green on HEAD; red HEAD blocks new picks until green — picking onto red is how respins multiply), (3) respin-budget check (RC count vs §22 ≤3 budget with burn-down stated; 3rd respin triggers the Arch split-or-slip decision pre-committed, not debated mid-crisis), (4) SBOM/transparency hygiene (§17 dir present for latest RC, SBOM diff vs RCn-1 attached to the respin MR — respins without diffs are rejected by the bot).

Bot duties (`release/garden-bot.yaml`, versioned): stale-pick nagger (pings pick owners at 3/7 days), oversize flagger (>300 lines adds `NEEDS-FULL-RUN` label per §22 interaction rule), missing-sign blocker (no QA sign = no merge, no Arch override for cross-cutting), clock watcher (bake-clock resets on kernel/boot/vbmeta/OTA-verify picks per §22 §26 — bot comments the reset with the invalidated prior bake dates so nobody "forgets"), thaw-blocker (merge-back MR must reference 7-day quiet evidence + §20 dashboard green + ch.10 §16 sign-off form link, else blocked). Bot config changes require Release + Arch sign (gardening automation is release infrastructure — unreviewed bot edits are process CVEs).

Pruning & protection: merged hotfix branches deleted within 7 days of thaw (bot files deletion MR, human confirms); abandoned release candidates (`RCn` superseded >30 days, no rollout) tagged `SUPERSEDED` + branch deleted after transparency snapshot archived (transparency dirs are append-only per §17 — branch deletion never deletes transparency); branch protection (require 2-sign picks, require green subset, dismiss stale reviews on new commits, block force-push — verified quarterly by intentionally attempting a force-push to a staging copy, push must fail with the protection message logged as the drill artifact).

Anti-pattern ledger (review rejects on sight): "just one more feature, it's small" (rides the train, never the frozen branch); cherry-pick-of-a-cherry-pick without root MR link (provenance or it didn't happen); thaw-by-fatigue ("we've respun 4 times, let's just ship RC4" — §22 budget forces the Arch review at RC4, gardening enforces the meeting happened); branch-unlock-for-hotfix (§22 bans it; gardening bot re-locks within 1h if a human unlocks, with an alert — the re-lock is automatic, the post-mortem is human).

## 26. OTA staged-rollout autopilot thresholds (1% → 10% → 50% → 100% with teeth)

Stage map (reaffirms §4, autopilot executes it): 1% (48h bake minimum) → 10% (48h) → 50% (48h) → 100%. Every stage has *auto-promote* conditions (all must hold) and *auto-halt* conditions (any one fires). Autopilot proposes promotions; humans confirm (§20 stage-promotion checklist dual-sign remains — autopilot never self-promotes past 10% without the named 48h-watch humans from ch.10 §16). All telemetry redacted per §4 report rules (versions, gate-times, failure stage; no IMSI — autopilot inputs are aggregates, never per-device identities).

Auto-halt thresholds (any one halts, freeze-at-current-stage per §20): rollback-rate >2% trailing 24h (the §4 invariant, per-stage gauge §20 panel 1); health-gate miss split breach (any single gate — container boot / radio-register / SMS-loopback per §9 — exceeding 1% absolute triggers halt even if total rollback <2%, because single-gate spikes localize the subsystem faster than the blended rate); crash-rate delta (rollout-stage P0/P1 per 1k device-days >2× dogfood baseline from ch.10 §§10/20 comparison report = halt — crash telemetry uses the ch.10 §10 taxonomy so baseline-vs-stage is apples-to-apples); download/verify funnel anomaly (verify-fail >0.5% or slot-write-fail >0.5% per §20 panel 4 = halt — verify failures implicate keys/rollback-index §15, slot-write failures implicate partitions §8, both are wrong-payload-class signals); manual halt (any signatory on ch.10 §16 form + on-call may halt with one command `halide-rollout halt <ver> --reason <id>` — halt latency SLA ≤15 min from decision to serving-freeze, drilled quarterly).

Auto-promote conditions (all required, checked at bake-clock expiry): bake clock elapsed (48h per stage, resets per §22 respin rules + any halt restarts the stage clock fresh — halted stages never "resume with credit"); rollback-rate <0.5% green sustained 24h (0.5–2% amber extends bake +24h once, then requires Arch review — amber is not green-with-confidence); no red panels on §20 dashboard (amber panels need owner notes linked in the promotion MR); fleet-mix minimums met (§20 panel 5: ≥2 SKUs + ≥3 carriers in the stage cohort, else extend bake — autopilot refuses to promote a single-SKU stage even at 0% rollback); download funnel complete (≥95% of the stage cohort reached commit-or-reported, else the stage sample is too thin to judge — autopilot extends, not promotes); 7-day dogfood still valid (dogfood gate per ch.10 §10 + 7-day rule reaffirmed — autopilot checks the sign-off form timestamp; dogfood older than the RC under rollout invalidates promotion until delta-soak per §22 completes).

Autopilot mechanics (`release/autopilot-<ver>.yaml` + `scripts/rollout-autopilot.sh`, both versioned): declarative thresholds file per release (values above as numbers, not prose — `rollback_halt_pct: 2.0`, `gate_miss_halt_pct: 1.0`, `crash_delta_halt_x: 2.0`, `bake_hours: 48`, `mix_skus_min: 2`, `mix_carriers_min: 3`, `funnel_complete_pct: 95`); hourly evaluation writing `release/rollout-<ver>.md` (same-numbers-both-places invariant §20 — autopilot output and human notes share the file, dashboard-vs-notes drift blocks promotion by bot check); every evaluation logged append-only (`release/autopilot-log-<ver>.jsonl`: timestamp, inputs, decision, threshold versions — post-halt archaeology per ch.10 long-tail process reads this log first); kill-switch (`halide-rollout autopilot-off <ver>` reverts to fully-manual §20 operation within 1h — autopilot-off drills annually, off-path must still enforce halt thresholds manually with the same numbers).

Canary discipline inside 1%: internal-fleet-first 24h (dogfood volunteers + lab spares, ch.10 §10 fleet, before any external 1% device is served — internal rollback >0% pauses external 1% until triaged); carrier-staggered entry (1% cohort spreads across carriers per §20 mix rule — single-carrier 1% stages are rejected by autopilot as unrepresentative); sideload parity (recovery sideload path §9 gates unchanged during rollout — autopilot monitors sideload-verify failures as a verify-funnel input, sideload doesn't bypass safety even mid-rollout).

Post-100% quiet week (links §22 thaw): autopilot keeps watching 7 days at green thresholds (any halt-condition breach post-100% opens a §21 hotfix-lane decision with owner + clock per §21 T+0 rule, not a silent "post-release issue"); quiet-week green + ch.10 §16 post-release 48h watch roster sign-off = merge-back + lock per §22. Abandoned-rollout guard: halted rollouts without a hotfix-vs-train decision logged within 24h page Arch (§20 decision-clock restated as an autopilot alert — autopilot nags, humans decide).

## 27. OTA payload delta-size budget table (full vs incremental, bsdiff/xz thresholds, 8GB cap enforcement)

Parent: §§4/9 payload engineering + §14 release-notes UPGRADE line + §§20/26 staged-rollout autopilot. Every release publishes both payload classes with byte counts in the notes (metered-link planning is a user promise, not a footnote); this section is the budget those numbers are judged against. Budgets are per-SKU ceilings committed in `images/<sku>/ota-budget.json` (full-cap, delta-cap, delta-fallback threshold, compressor, block size); `scripts/ota-budget-check.sh` enforces them in the §11 release job before signing (oversize = fail with byte counts + offender partition, never silent truncate, same doctrine as §8 oversize-fail). All sizes measured as wire bytes (`payload.bin` + `payload_properties.txt` + `metadata.json` on the wire, not unpacked partition sums — users download wire bytes).

| Payload class | Typical size (REF-A/B, erofs §8) | Budget cap (per-SKU default, overridable in ota-budget.json with ADR) | Compressor / diff | Threshold rule (binding) | On breach |
|---|---|---|---|---|---|
| Full OTA (`full-payload.bin`) | 2.2–3.8G (super 9G sparse + host 3.5G erofs compressed) | 4.5G hard cap per payload; combined full + metadata + signatures ≤5G | `xz -9 --threads=0` (or `zstd --long -19` where update_engine build enables; compressor pinned per release in MANIFEST.lock, never floated) | always generated; staged-rollout 1% cohort must include ≥10% full-payload updaters (delta-only 1% stages hide full-path bugs — §26 mix rule extended) | cap breach blocks signing; owner Release + Arch review: split partitions (host.img diet), grow cap only with ADR + mirror-retention check (§19 retention ≥2 releases × new size) |
| Incremental OTA (`incremental-<from>-to-<to>.bin`) | 150–600M month-to-month (erofs-stable blocks dedupe well); 0.8–1.5G across kernel-major or Mesa-major bumps | 1.2G soft cap / 2.0G hard cap | `bsdiff` ( executables/kernel Image.gz) + `puffdiff`/`imgdiff` (erofs images, 4K-block) + `xz` envelope; `bsdiff` memory cap 512M per worker (OOM guard on builders — §23 builder disk/class rules apply) | generate incremental iff `bsdiff/xz` output ≤60% of full-payload size AND ≤2.0G hard cap; else ship full-only + record `delta-skipped:<reason>` in notes (100M cap in §9 restated here as the per-file chunk cap inside the envelope: single-file bsdiff hunks >100M fall back to full-file deflate for that file, logged per-file in `logs/ota-diff-<ver>.json`) | soft-cap breach warns + requires notes line ("large delta: kernel bump, prefer Wi-Fi"); hard-cap breach drops the incremental (full-only release, autopilot funnel §20 must show full-path commits ≥95% before promote) |
| Downgrade-block metadata (`payload_properties.txt` + `metadata.json`) | 4–8K | 64K | n/a (signed, uncompressed) | must carry `version-from/to`, wire size, required-battery ≥30% + charger-or-override, changelog URL, `deadline` for security updates (§9), rollback-index (must exceed current or device refuses — §4 verify restated as budget row because a missing index field bricks the funnel) | missing field = signing blocked (§15 verbal-check includes reading rollback + battery fields aloud) |
| Sideload bundle (recovery §9 path) | = full payload + 1M recovery wrapper | same 4.5G cap as full | same compressor as full | identical verify+health gates (sideload never cheaper on safety even if larger on disk) | oversize sideload falls back to two-part sideload (`--split 2G` chunks with per-chunk SHA, documented in runbook-recovery) |
| Fleet-cumulative cap (the 8GB rule) | per-device download per release cycle | 8GB combined cap: `full + Σ served incrementals + 1 retry of each` ≤8G per from-version | n/a (accounting rule) | `scripts/ota-budget-check.sh --fleet-cap` sums the published set per from-version; breach = prune incremental graph (drop oldest from-version deltas first, keep N-1 → N and N-2 → N minimum) or split the release (ship blockers now per §22 split-or-slip) | cap breach blocks transparency publish (§17 dir incomplete without the cap attestation line) |

`bsdiff`/`xz` threshold detail (so "delta bigger than full" never ships): diff workers run with `--block-size 4096` matching erofs `-C4096` (§8 — mismatched block sizes halve dedupe; CI asserts the match), dictionary reuse across consecutive releases (dictionary = previous `super.img` sparsified header, stored in artifact store with SHA, 90-day retention), and per-partition decision (system/vendor/product/host diffed independently; a kernel-major bump may force full `boot.img` while `system` still deltas — the payload mixes per-partition strategies and the notes table shows per-partition full/delta bytes, not one blended number). `xz` integrity: `--check=crc64` + `payload.bin` hash-chunks verified on device before slot write (§9 download→verify restated; corrupt-chunk resume never skips the final full-image SHA).

8GB cap enforcement (mechanical): `ota-budget.json` per SKU (`{sku, full_cap_B, delta_soft_B, delta_hard_B, fleet_cap_B: 8589934592, compressor, block_size, dictionary_sha}`); `ota-budget-check.sh` runs after `build-all.sh` stage 7 and emits `logs/ota-sizes-<sku>-<ver>.json` (wire bytes per artifact, per-partition breakdown, delta-vs-full ratio, fleet-cap sum, PASS/FAIL + offender). Release job wires the output three places: (a) §14 UPGRADE line auto-filled from the JSON (humans add the "prefer Wi-Fi" sentence, never the numbers), (b) §17 transparency dir includes the JSON + the compressor pin (third-party mirrors §19 serve-after-verify covers size claims too — mirror healthz exposes wire SHAs + sizes), (c) §20 funnel panel gains a `payload-class` split (full vs incremental commit rates tracked separately — a delta-only regression hides inside a blended funnel, the split exposes it). Nightly exemption: nightlies publish full-only (no delta graph — §12 fossil-prevention + lab-only audience), but the size JSON is still emitted so growth trends alert at 90% of cap (same growth-trend doctrine as §18 `lpmake` row).

Expected outputs: `images/<sku>/ota-budget.json` (caps + compressor pin); `logs/ota-diff-<ver>.json` (per-file diff strategy + hunk sizes + fallback reasons); `logs/ota-sizes-<sku>-<ver>.json` (wire bytes, ratios, fleet-cap sum, PASS/FAIL); release-notes UPGRADE table (full/delta wire sizes + battery + staged % + `delta-skipped` reasons where applicable); transparency `ota-sizes` attestation line (sizes + SHAs + rollback-index).

- [ ] Full payload ≤4.5G wire and fleet-cap sum ≤8G per from-version (JSON PASS attached to release).
- [ ] Incremental shipped only when ≤60% of full AND ≤2.0G hard cap, else `delta-skipped:<reason>` in notes.
- [ ] Per-partition full/delta bytes published (no blended single number); `xz --check=crc64` + hash-chunk verify on device.
- [ ] Sideload bundle meets identical verify+health gates with per-chunk SHA where split.
- [ ] Autopilot funnel shows payload-class split (full vs incremental commits) before each promotion.

## 28. Factory station network-isolation spec (VLAN, airgap signing, USB allowlist)

Parent: §10 flash runbook + §16 flash-station tooling + §15 signing ceremony + ch.08 §§8/19 key custody. The factory laptop that flashes user devices is a privileged attacker position (it writes bootloaders); this section isolates it so a compromised office LAN or a stray USB stick cannot become a fleet compromise. Applies to every station running `factory/flash-station/` (in-house lines, RMA benches, carrier-lab loan benches per carrier-lab-handbook); a station that cannot meet this spec is labeled `UNISOLATED-LAB-ONLY` (flashes testkey/eng builds only, release-image flashing refused by tooling — the label is enforced in software, not signage).

Network isolation (VLAN + firewall, committed in `factory/station-net.md` with diagram): stations live on a dedicated `FLASH-VLAN` (untagged access ports, no trunk to office LAN; DHCP + DNS from the lab router only; inter-VLAN default-deny with exactly three allowlisted egress paths: (1) canonical git/artifact host for fetching `flashmap.json` + release images (SHA-verified post-fetch against `SHA256.signed.txt` §17 — fetch-then-verify, never trust-the-wire), (2) transparency repo read-only (commit-SHA pinned per flashing session, logged per unit), (3) NTP (single pool host, logged). All other egress (web, mail, package mirrors, telemetry) denied at the router + host `nftables` (§16 station inherits the ch.08 §10 default-deny posture: ruleset committed as `factory/station-nftables.conf`, `nft list ruleset` diffed at shift start by `station-selftest.sh`). Wi-Fi on the station: disabled in BIOS + rfkill-blocked + `station-selftest.sh` asserts `iw dev` shows no associated interface (a station that wandered onto office Wi-Fi fails selftest and refuses to flash — roaming is the bypass this kills). Remote access into the station (SSH for QA spot-checks): ed25519 bastion-only, no password, idle-timeout 5 min, session log shipped at shift end with the flash logs (§16 append-only discipline extended).

Airgap signing separation (the station never signs): release private keys live on the §15 offline signer (ch.08 §19 room), never on any FLASH-VLAN host (CI greps station images for `PRIVATE KEY` blocks like the §3 testkey grep — hit = quarantine the station image + rotate its deploy keys per §13 ladder). Station-side verify-only flow: station holds release pubs (`keys/*.x509.pem` + `key-metadata.json` fingerprints) and runs `avbtool verify_image` + `sha256sum -c` post-write per §16 verify-after-write (verify failures halt the line per §16 big-red-halt + ch.09 §13 hash-mismatch freeze). SIGN-X USB sticks (§15) never touch a station (sticks travel builder→signer→publisher only; a SIGN-X stick inserted into a station is a process fail logged + stick retired — the rule is written here so helpful technicians can't "save a trip"). Ceremony-to-factory chain: station flashing session header records transparency-commit id + `signatures.json` key-ids + rollback-index (same three values the §15 verbal check read aloud — factory confirms what ceremony attested, closing the loop).

USB allowlist (stations are USB-hostile by default — evil-stick discipline): host USBGuard policy committed as `factory/usbguard-rules.conf` (allowlist, not denylist); `station-selftest.sh` asserts USBGuard running + policy SHA matches committed before first flash of the shift.

| USB class / device | Policy | Rationale + procedure |
|---|---|---|
| Target phones in fastboot/adb (VID:PID per `hw/<sku>/edl.md` + flashmap) | ALLOW (serial-bound: only units claimed in the shift manifest; unknown serial = prompt + log, never auto-flash) | flashing is the job; serial-binding stops cross-SKU flash (§16 mismatch-halt restated as USB rule) |
| SIGN-X ceremony sticks | DENY + alert (insertion pages line lead, stick retired per airgap rule above) | ceremony/factory separation is load-bearing (§15 chain); convenience insertion is the compromise path |
| Operator backup disks (GPT/persist backups §16) | ALLOW single-purpose labeled `BACKUP-X` ext4 sticks only (scanned both sides quarterly per ch.08 §23 factory-row; retired annually) | backup-first gate needs a write target; single-purpose + scan discipline bounds the malware surface |
| Network/Wi-Fi dongles, BT dongles, serial consoles beyond the booked UART rig | DENY (no station network extension past FLASH-VLAN; lab-runner UART ACLs ch.09 §23 apply to debug rigs, not stations) | a second network path silently voids the VLAN isolation; debug on lab-runners, flash on stations |
| Mystery/unlabeled media | DENY + bin (ch.10 §22 unlabeled-media rule applies verbatim on the line) | every stick dated-labeled or binned; line lead audits the bin weekly |
| HID keyboards/mice | ALLOW wired only (no wireless HID receivers — radio receivers are unreviewed USB network devices for isolation purposes) | technician usability without a wireless bridge onto the VLAN |

Station hardening + drills: station image pinned like §23 runners (Debian digest + `ci/packages.lock`-style freeze + `factory/station-image.md` definition; re-image ≤30 min or decommission, same bar as runners); full-disk encryption (TPM-sealed where present else sealed-envelope passphrase per ch.08 §8 model); per-shift `station-selftest.sh` (VLAN egress probe: allowed-3 reachable + office-LAN + internet unreachable with the failure named; `nft` diff clean; USBGuard SHA match; no `PRIVATE KEY` material; disk ≥20G free; clock/NTP sane — clock skew voids signature timestamps, so skew fails the shift); quarterly isolation game-day (plug an office-LAN cable into a staging station + insert a mystery stick → selftest must refuse flashing before any unit is touched; refusal-failure = P0 infra bug per §23 game-day doctrine). Logs: per-unit `factory/logs/<unit>-<date>.log` (§16) gains a session-isolation header (VLAN id, egress-probe result, USBGuard policy SHA, transparency-commit id, image SHA of the station itself — isolation evidence rides with every flashed unit, not in a separate binder an auditor never finds).

Expected outputs: `factory/station-net.md` (VLAN diagram + allowlisted-egress-3 + firewall rules); `factory/station-nftables.conf` (committed default-deny); `factory/usbguard-rules.conf` (allowlist + SHA); `factory/station-image.md` (pinned definition + re-image recipe); per-unit log isolation header (VLAN + probe + policy-SHA + transparency id + station-image SHA); quarterly game-day report (`factory/isolation-drill-<date>.md`).

- [ ] Station on FLASH-VLAN with 3-egress allowlist only (office-LAN/internet unreachable, selftest green at shift start).
- [ ] Wi-Fi absent/blocked and asserted (`iw dev` clean) before first flash; remote SSH bastion-only with session logs.
- [ ] No private-key material on any station (grep green); SIGN-X sticks never touch stations (insertion = retire + log).
- [ ] USBGuard allowlist enforced (policy-SHA logged per unit); mystery media binned, wireless HID denied.
- [ ] Per-unit logs carry isolation headers; quarterly VLAN + mystery-stick game-day passes and is filed.

Shift-handoff audit packet (so isolation evidence survives shift changes): at shift end the station emits `factory/logs/shift-<date>-<shift>.json` (units flashed count, transparency-commit id, station-image SHA, USBGuard policy SHA, egress-probe PASS/FAIL, `nft` diff hash, backup-disk SHAs, anomalies-or-"none" — the §15 ceremony-log discipline reused at factory scale: a missing `anomalies` line fails the packet, and a packet without the station-image SHA is treated as unsigned). Line lead countersigns within 24h (dual-control mirrors ch.08 §8 ceremony at line speed); unsigned packets page Release per §18 triage (unlogged flashes don't count toward the §10 ≤12-min metric, unisolated flashes don't count toward shipment). RMA-bench exception path (documented, never verbal): off-VLAN RMA bench flashes only with `UNISOLATED-LAB-ONLY` label + testkey/eng images + per-unit `RMA-UNISOLATED` log tag; any release-image flash attempt on that bench is refused by tooling and logged as a process near-miss reviewed in the quarterly isolation game-day. Audit sampling (`scripts/station-audit.py`, weekly QA, redacted logs only): 20 random per-unit logs re-verified (VLAN header present, policy-SHA matches committed, transparency id resolves, image SHAs verify) + 1 full shift-packet reconciliation (unit count vs traveler stickers vs backup SHAs); miss = lab-infra P1 per ch.10 §11 runbook with MTTR tracked.

- [ ] Shift packets complete with anomalies line + countersign ≤24h; unsigned packets page Release within 4h per §18 SLA severity.
- [ ] Weekly station-audit samples 20 unit logs + 1 shift reconciliation (miss = lab-infra P1 with MTTR tracked and game-day input filed promptly each time).
- [ ] OTA size JSONs retained 180 days with artifacts (§11 retention); growth-trend alert at 90% of any cap reviewed in gardening (§25) with owner + prevention item per §18 close-out doctrine.

## Verification

- [ ] Fresh builder reproduces `super.img` hash (modulo listed fields).
- [ ] A→B→A OTA preserves data; forced bad slot rolls back automatically.
- [ ] Testkey can never ship (CI gate green + manual `avbtool info` attached to release).
- [ ] Non-engineer completes factory flash from runbook ≤12 min without assistance.
- [ ] SBOM diff published; nightlies expire on schedule.
- [ ] Build-failure triage runbook exercised: last BUILD-BLOCKED has issue + prevention item.
- [ ] Mirror weekly byte-audit green; user verify procedure works from a mirror fetch.
- [ ] Rollout dashboard shows stage mix minimums before each promotion; halt drill logged.
- [ ] Hotfix 24h-clock drill passed within quarter (report filed, no skipped ceremony checks).
- [ ] RC respin count ≤3; boot-touching respins restarted the bake clock with evidence.
- [ ] Release tag signed in ceremony; branch merged to develop and locked read-only post-quiet-week.
- [ ] Thaw checklist archived with the tag (transparency dir complete, notes published).

Next: `10-test-cts-power-perf.md`.
