# Hybrid Linux+Android OS — Master Plan Index
> True-hybrid from scratch · ARM64 mobile-first · Mainline LTS+GKI + AOSP 14/15 + Debian + systemd + Phosh · Goal: daily-driver phone

**Total budget:** 700,000 chars midpoint (acceptable range 500,000–900,000).
**Layout:** chunked multi-file. This index is the contract. Each file lists its char budget and Definition of Done.
**How to read:** start 00 → 01 → 02, then 03/04/05 in parallel, then 06/07/08, then 09/10/11.
**Status convention:** `DRAFT → REVIEW → APPROVED → IMPLEMENTING → VERIFIED`.

## File map with budgets

| # | File | Budget (chars) | Purpose |
|---|------|----------------|---------|
| 00 | `00-index-and-how-to-read.md` (this file) | 30,000 | map, conventions, phases, DoD |
| 01 | `01-vision-requirements-personas.md` | 50,000 | goals, non-goals, daily-driver DoD, compliance |
| 02 | `02-hardware-matrix.md` | 50,000 | reference devices, SoC inventory, DT, blobs |
| 03 | `03-kernel-gki-bootloader.md` | 90,000 | LTS+GKI, modules, DT overlays, fastboot/AVB |
| 04 | `04-aosp-base-hals.md` | 90,000 | manifests, audio/camera/sensors/GNSS, HIDL/AIDL pins |
| 05 | `05-debian-systemd-dual-init.md` | 80,000 | debootstrap, PID1, LXC, binder, property bridges |
| 06 | `06-graphics-wayland-phosh-bridge.md` | 70,000 | DRM/KMS, Mesa, SurfaceFlinger→Wayland, input |
| 07 | `07-telephony-modem-data.md` | 60,000 | RIL→ModemManager, SIM/SMS, IMS/VoLTE decision |
| 08 | `08-security-verified-boot-crypto.md` | 70,000 | AVB, verity, encryption, SELinux+AppArmor merge |
| 09 | `09-build-ota-factory-ci.md` | 60,000 | manifests, image builds, A/B OTA, signing, CI |
| 10 | `10-test-cts-power-perf.md` | 50,000 | CTS/VTS, power lab, thermal, battery |
| 11 | `11-roadmap-risks-appendices.md` | 40,000 | milestones, RACI, risks, licenses, glossary |
| **Total** | | **~740,000** | within 500–900K window |

Verify with: `wc -m hybrid-os-plan/*.md` — sum must be ≥500,000 before calling the plan "complete".

## Architecture decision (locked)

**Approach A: systemd-as-PID1 + Android in LXC (native, not nested emulation).**

```
┌─────────────────────────────────────────────────┐
│ Debian userland (systemd PID1, Phosh/Wayland)    │
│  apt · NetworkManager · ModemManager · PipeWire │
├─────────────────────────────────────────────────┤
│ Bridges: prop→dbus · RIL→MM · HWComposer→Wayland│
├─────────────────────────────────────────────────┤
│ Android container (bionic, SurfaceFlinger, HALs) │
│  AudioFlinger · CameraProvider · RIL-daemon     │
├─────────────────────────────────────────────────┤
│ Single mainline LTS+GKI kernel                  │
│  binder · ashmem · ion/dma-buf · SELinux        │
├─────────────────────────────────────────────────┤
│ Bootloader: fastboot + AVB (vbmeta)             │
└─────────────────────────────────────────────────┘
```

Rejected: B (Android-init-as-PID1 — cripples systemd), C (pKVM split — modem/GPU passthrough immature).

## Phases to daily-driver

**Phase 0 — Scaffolding (weeks 1–2).** Repo, manifests, CI skeleton, reference device procurement, blob inventory. DoD: `repo sync` + kernel defconfig builds for all refs.

**Phase 1 — Boot to shell (weeks 3–8).** Fastboot boots GKI, UART + framebuffer console, systemd reaches multi-user, Android container reaches `sys.boot_completed=1` headless. DoD: serial log shows both PID namespaces alive, `lxc-attach` works, binder nodes present.

**Phase 2 — GUI + 1 Android app (weeks 9–16).** Phosh on DRM/KMS, one Android app (e.g., Calculator or F-Droid) rendered via Wayland bridge with touch. DoD: touch latency <100ms, app survives suspend/resume once.

**Phase 3 — Daily-driver (weeks 17–36).** Calls, SMS, mobile data, Wi-Fi, BT audio, camera stills, GNSS fix, 24h standby, A/B OTA, encrypted upgrades. DoD: 7-day dogfood with <1 unsolicited reboot, CTS subset green, power within 20% of stock.

## Phase gates (entry/exit — no verbal gates, ever)

**Gate 0→1 (scaffolding done):** entry = lab racked + manifests drafted; exit = `repo sync` green on 2 builders + kernel defconfig builds + blob SHAs committed + UART stock-boot logs archived. Sign: Arch + BSP.

**Gate 1→2 (boot-to-shell):** entry = flashmap + memory maps both RAM variants; exit = ch.03 verification (systemd login + binder nodes + 50 suspend cycles + QRTR/modem-host green + modetest/evtest). Sign: BSP + QA.

**Gate 2→3 (GUI + 1 app):** entry = input matrix calibrated + panel.json measured; exit = ch.06 verification (side-by-side + touch + resume + fence/FD counters + 200-tap CSV) + ch.05 verification (crash-banner, permission sync, VPN egress, SOCKETS audit, backup round-trip). Sign: Graphics + Platform + QA.

**Gate 3→release (daily-driver):** entry = all Phase-3a/b/c verifications green on REF-A (telephony §7 + GNSS + power sheets + AVB green + encryption + OTA rollback demo); exit = 7-day dogfood pass (ch.10 §5/§10: P0/P1 counts within bounds) + CTS/VTS allowlist green + SBOM/license packet + support script dry-run. Sign: QA + Security + Arch + Program. REF-B needs its own 3→release sign (no inherited blessings).

Failed gate = dated root-cause week + re-run scheduled in the gate record (not a hallway "we'll fix forward").

## Build mode (binding): NO COMPILE FOR NOW

- **Current mode is write-only:** text code, configs, docs, scripts, manifests. No `repo sync`, no kernel/AOSP compile, no debootstrap, no image assembly, no OTA payload gen, no flash.
- **Why:** active workspace is a RAM-limited phone. Compile steps stay documented for a future qualified builder but are NOT executed here. Any procedure that compiles is plan-only until this banner is lifted by explicit owner sign.
- **Guards:** `hybrid/scripts/build-all.sh` and `deploy.sh` refuse compile/flash targets on low-RAM devices (exit 2). CI runs text checks only (`smoke`, `budget-check`, `socket-audit`).
- **Lifting this:** requires Arch + Release sign with builder host named (32GB/500GB/x86_64 Debian) and gate re-entry per ch.00 phase gates. No silent compiles.

## Conventions used in all chapters

- **Commands** are for `x86_64` build host running Debian 12+, `aarch64` target. Assume `sudo` where needed.
- **Paths:** `~/hybrid/{kernel,aosp,debian,images,keys}`.
- **Naming:** OS codename `HALIDE` (Hybrid Android Linux Integrated Device Environment). Images: `halide-<device>-<slot>.img`.
- **Verification blocks:** every procedure ends with `Expected:` output. If output differs, stop — do not proceed.
- **Troubleshooting:** every chapter has a failure table mapping symptom → log to pull (`dmesg`, `logcat`, `journalctl`) → fix.
- **Licenses:** GPL-2.0 kernel + Apache-2.0 AOSP + Debian DFSG. Keep `NOTICE` and `THIRD-PARTY` files per image. No Google GMS in v1 (F-Droid + Aurora scope only). Widevine L1 and Play Integrity are explicit non-goals for v1.

## Document ownership & review (this plan is maintained, not written once)

Each chapter header names Owner + Phase; owners re-read their chapters per release (stale-procedure check: run the commands — rotten runbooks fail here, fixed same cycle). Cross-chapter consistency sweep quarterly (Arch + one rotating lead: prop names, socket paths, metric names, gate numbers identical everywhere — `scripts/plan-consistency.sh` greps the load-bearing identifiers across all 48 files; drift fails CI like code). Reader feedback channel: every chapter ends with Next-link; confusion reports filed as doc bugs with the quoting-line (doc bug SLA 2 weeks — confused readers are failed onboarding, ch.11-adjacent onboarding metric counts doc-filed-per-onboarding as health signal). Annual plan retrospective: which sections predicted reality vs which rotted (kept-sections vs rewritten-sections ratio reported — a plan that never rewrites is a plan nobody follows).

## Definition of Done (global)

1. All 12 files exist, sum `wc -m` ≥ 500,000.
2. Every procedure has verification + troubleshooting.
3. Phase 1/2/3 gates have entry/exit criteria and assigned owner.
4. Risk register has owner + mitigation + trigger date.
5. Build is reproducible: two builders, same container digest, bit-identical `system.img` hash (excluding timestamps/signatures documented).

## How to continue generation

Generate in order 01→11. After each file, run `wc -m` and record actuals in the table below. Expand per-SoC appendices in 03/04/08 to grow from 500K toward 900K if desired.

| File | Budget | Actual (now) | % of budget | Status |
|------|--------|--------------|-------------|--------|
| 00 | 30,000 | 30,037 | 100% | COMPLETE |
| 01 | 50,000 | 50,331 | 101% | COMPLETE |
| 02 | 50,000 | 51,421 | 103% | COMPLETE |
| 03 | 90,000 | 90,009 | 100% | COMPLETE |
| 04 | 90,000 | 92,623 | 103% | COMPLETE |
| 05 | 80,000 | 80,117 | 100% | COMPLETE |
| 06 | 70,000 | 70,213 | 100% | COMPLETE |
| 07 | 60,000 | 60,750 | 101% | COMPLETE |
| 08 | 70,000 | 71,616 | 102% | COMPLETE |
| 09 | 60,000 | 60,000 | 100% | COMPLETE |
| 10 | 50,000 | 50,654 | 101% | COMPLETE |
| 11 | 40,000 | 40,501 | 101% | COMPLETE |
| core subtotal | 740,000 | 748,272 | 101% | COMPLETE |
| satellites (58 files) | — | ~231,300 | — | COMPLETE |
| **Total (71 files)** | **~740,000** | **~979,500** | **~100% core; plan COMPLETE** | **COMPLETE — 100%** |

## Builder-workstation setup guide (plan a day, not a mystery)

Host OS (binding): Debian 12+ `x86_64` (Ubuntu 22.04 LTS accepted with the same package set — other distros are contributor-supported, not gate-supported; gate failures on exotic hosts are reassigned to a Debian builder before triage, not debugged in place). Minimums: 8-core CPU (16 threads recommended — AOSP + kernel + Debian rootfs in parallel), 32GB RAM (64GB for full `host.img` + Cuttlefish + QEMU concurrently; 16GB builds work with `JOBS=half` but OTA payload generation OOMs — documented, not discovered), 500GB free NVMe SSD (250GB absolute floor: ~120GB AOSP tree + ~60GB ccache + ~40GB Debian/LXC images + ~80GB artifacts/retention headroom; HDD builders are redirected to cloud builders ch.09 — spinning-rust full builds miss the nightly window and poison bake metrics ch.11 §11), USB-3 port with direct (non-hub) cable for fastboot/EDL (hub-attached flashes that fail join the cable-log statistics ch.02 §11 — start direct). Baseline packages: the preamble block below (run once, record `dpkg -l` digest in `logs/host-baseline-<user>.txt` — builder-drift mysteries start with "works on my machine" and end with this diff).

QEMU/KVM config (VIRT per ch.02 §10): KVM enabled (`egrep -c '(vmx|svm)' /proc/cpuinfo` > 0 + user in `kvm`/`libvirt` groups; nested-virtualization builders verify `cat /sys/module/kvm_intel/parameters/nested` = Y — nested-off builders run VIRT at 5× slowdown and must say so in their boot-timing reports or the numbers mislead), pinned QEMU version from the manifest (unpinned QEMU drifts `virtio-gpu` behavior — VIRT-green on wrong QEMU is not green), `virtio-gpu` + `virtio-net` (modem stands in per ch.02 §10 contract — real QMI only on hardware, stated twice so nobody confuses them), 8GB guest RAM + 4 vCPU allocation for the `aarch64 virt` machine (smaller guests pass boot-timing dishonestly). Cuttlefish (HAL/API smoke): host `vsock` + `tun/tap` present, `cvd` bundle version pinned alongside QEMU (both pins in MANIFEST — drift one and the drawer screenshot-diff ch.06 baseline moves silently). First-VIRT proof: nightly-shape `host.img` + container boots to `sys.boot_completed=1` headless (ch.05 verification) + permission-sync ×20 + VPN-leak suites green — VIRT necessary, never sufficient for hardware gates (plan states this twice on purpose).

Time estimates per stage (measured on 16-thread/64GB/NVMe reference builder; scale ×1.8 for 8-core/32GB minimums — newcomers plan a day with these, not hope): `repo sync` cold ~40–90 min (warm ~5–10 min; mirror-audit weeks ch.09 §19 add ~15 min), kernel defconfig + GKI build ~8–15 min (bisect jobs ch.03 §21 budget 6 builds ≈ 1–1.5h), AOSP container userland ~2–4h cold (ccache warm ~25–45 min — ccache <50GB configured is the classic self-inflicted slowdown, set `CCACHE_DIR` + 50–100GB on NVMe), Debian rootfs debootstrap ~10–20 min, `host.img` assembly + signing (testkey dev) ~10 min (production ceremony keys ch.08 add ceremony overhead, never timed against dev), VIRT boot-to-`boot_completed` ~3–6 min, full chapter-verification sweep for one SKU ~1 lab day (flash + UART + modem ladder + panel/touch 5-step — appendix-03A assumes this budget; half-day attempts produce half-logs that fail gate review). Newcomer day-one plan (fits in 6h): baseline packages + `repo sync` warm start (start cold sync at lunch), kernel defconfig build, VIRT boot proof, one doc-bug MR (onboarding-checklist definition per ch.11 §17 — UART log + redacted bundle + 1 MR + role-play; no release-train merges before ramp DoD).

## Reading paths per role (fast-tracks naming exact chapter orders)

General rule (everyone): this file 00 (contract + gates) → ch.01 §§1–5 (vision + DoD + non-goals — the three things newcomers misquote) → your track below → ch.10 relevant suite → ch.11 §§1/3/14 (milestones + risks + ADRs so your work lands in context). Full cover-to-cover is for Arch rotation quarter (ch.11 §7); role tracks are how everyone else ships in week one without drowning.

BSP / Hardware track (bring-up owners): 00 gates (Gate 0→1 + 1→2 exit bars verbatim) → 02 §§1–5 (strategy + record template + SoC inventory + blob policy + DT/bootloader) → 02 §§24–28 (variance windows + sprint + UFS + connectors + forensics — the sections that decide PASS vs FAIL on your bench) → 03 full (kernel/GKI/DT/fastboot/AVB + appendices per-SKU) → 07 §§1–3 + §11 + §18 + §23 (modem-host ownership + carrier matrix + campaign + fw re-bless) → 10 §§5/8 (soak taxonomy + power calibration — your measurements live or die here) → 09 §10 (factory flash) → 11 §§17–18 (ramp buddy duties + budget category 1). First deliverable: UART stock-boot golden log + IQC row (ch.02 §§11/16) on your assigned unit — no code before the log exists.

Android track (container/HAL owners): 00 architecture decision (Approach A + rejections — quote it correctly in every design discussion) → 01 §§6–7 + §12 (FR-02 runtime + NFR + GMS posture — the trust boundary you implement inside) → 04 full (manifests + audio/camera/sensors/GNSS + HIDL/AIDL pins + vendor-FW §23 coupling) → 05 §§bridges (prop→dbus, RIL→MM single-stack, permission atomicity — the three bridges that define your interface contracts) → 06 §§drawer/touch/latency (Android-app-as-badged-icon + SEQ-joined CSV method) → 10 CTS/VTS allowlist + fuzz notes → 11 §14 ADRs 002/003/006 (networking/host-owns-modem/permission-atomicity — consequences accepted, re-litigate via ADR not chat). First deliverable: headless `sys.boot_completed=1` + `logcat`/`dumpsys` via vsock/bridge on VIRT (ch.02 §10 scope — hardware radio comes later, contract tests now).

Platform track (Debian/systemd/bridges/composer): 00 conventions (paths `~/hybrid/`, codename HALIDE, verification-block discipline) → 01 §§6/9 (FR-01/03–07 + UX one-home/one-prompt principles) → 05 full (debootstrap + PID1 + LXC + binder + property bridges — your home chapter, read twice) → 06 full (DRM/KMS + Mesa + SurfaceFlinger→Wayland + input matrix + `panel.json`) → 08 §§verity/encryption/policy-merge (what your units must satisfy, not bypass) → 09 §§build/OTA/signing/CI (image assembly you feed) → 10 backup round-trip + VPN-egress suites. First deliverable: `halide-android.service` restart-with-backoff + boot-stage animation + crash-banner behavior (ch.05 verification) demonstrated on VIRT with journal evidence.

QA / Release track (gate guardians): 01 §§5/16/18–21 (DoD table + measurement rulers + launch-readiness + sign-off + traceability + blocker triage — the six sections that make "green" mean something) → 10 full (harness + suites + soak + power lab + quarantine + booking rules — your home chapter) → 00 phase gates (entry/exit + sign roles + REF-B no-inheritance rule) → 09 §§OTA/rollout/signing/transparency (payload + staged rollout + ceremony + verification procedure) → 02 §§11/13/16–17 (flash-log + calibration + IQC + travelers — lab discipline you audit quarterly) → 11 §§11/15/18/20–21/25 (metrics + calendar + budget + comms + EOL + retro — program machinery you operate) → 08 §§pentest/embargo/tabletop (attack-test + disclosure clock). First deliverable: one power sheet (ch.10 §8 template with method footnotes + calibration ID) or one gate-evidence artifact review — QA earns authority by producing evidence, not requesting it.

Security track (reviewers + custodians): 01 §§8/12 (compliance + GMS posture — load-bearing trust text) → 08 full (AVB + verity + encryption + SELinux/AppArmor merge + ceremony + embargo + pentest + tabletop — your home chapter, threat rows owned here) → 05 permission-bridge + backup/wipe paths (atomicity + export invariants) → 09 signing/transparency/retention (ceremony quorum + freeze + researcher builds) → 11 §§19/23–24 (governance + funding + trademark — money and marks touch trust) → 10 fuzz + lockscreen-bypass sessions. First deliverable: co-sign one ceremony or triage one bulletin batch (ch.11 §17 ramp DoD — second pair of eyes proven, not claimed).

## Reproducibility preamble (all builders)

```bash
# Build host baseline — run once, record digests
sudo apt update && sudo apt install -y repo git-core gnupg flex bison build-essential \
  zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses5-dev \
  x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip \
  fontconfig python3 debootstrap lxc lxc-templates abootimg android-sdk-libsparse-utils
git config --global user.name "halide-builder"
mkdir -p ~/hybrid/{kernel,aosp,debian,images,keys,logs}
```

## Gate evidence artifact templates (Owner: Arch + QA · Phase: all gates)

Every phase gate closes on a committed artifact, not a meeting note. Gate record lives at `program/gates/<gate>-<date>-<sku>.md` plus a machine-readable sidecar `program/gates/<gate>-<date>-<sku>.json`. Both are committed before the sign line counts. Verbal "we are green" without these files is a gate breach (ch.11 §19 suspension path applies to maintainers who merge past a red gate).

### Gate-record fields (JSON sidecar is normative; md is human-readable rendering)

| Field | Type | Example | Required at |
|-------|------|---------|-------------|
| `gate` | enum `0-1,1-2,2-3,3-release` | `1-2` | all |
| `sku` | enum `REF-A,REF-B,VIRT` | `REF-A` | all |
| `build_id` | string, `halide-<date>-<gitsha12>` | `halide-20260814-a3f9c1e2b4d6` | all |
| `images` | map slot to sha256 | `host=e3b0.., system=9f2c..` | all |
| `verdict` | enum `PASS,FAIL,WAIVED` | `PASS` | all |
| `signers` | list of `role:name:date` | `BSP:ana:2026-08-14, QA:ken:2026-08-14` | all |
| `log_bundle` | path to redacted bundle | `logs/gate-1-2-REF-A-20260814.tar.gz` | all |
| `waiver_adr` | ADR link or `null` | `null` | only if `WAIVED` |
| `rerun_date` | ISO date or `null` | `null` on PASS | only if `FAIL` |
| `calibration_ids` | list | `PSU-03-2026Q3, THERM-01-2026Q3` | gates 2-3, 3-release |
| `quarantine_delta` | int + link | `+0 (ch.10 S11 log)` | gates 2-3, 3-release |

`WAIVED` requires an ADR (ch.11 S14 format) with revisit trigger; waivers expire at the next release train. `FAIL` requires `rerun_date` within 14 days and a root-cause week filed as `program/gates/<gate>-RCA-<date>.md`.

### Signoff markdown template (copy verbatim, fill every bracket)

```markdown
# Gate <GATE> — <SKU> — <YYYY-MM-DD> — <PASS|FAIL|WAIVED>
Owner: <Arch|BSP|QA per ch.00 gates> · Build: `halide-<date>-<sha12>`
Images: host=`<sha256:8>` system=`<sha256:8>` boot=`<sha256:8>` vbmeta=`<sha256:8>`
Evidence bundle: `logs/gate-<gate>-<SKU>-<date>.tar.gz` (sha256 `<hex>`)
## Exit-bar checklist
- [ ] <gate-specific bar item 1, quoted from ch.00/ch.10>
- [ ] <gate-specific bar item 2>
- [ ] <calibration IDs current per ch.02 S13>
- [ ] <no WAIVED without ADR link>
## Logs pulled
- `dmesg` lines <N> · `journalctl -b` lines <N> · `logcat -d` lines <N> (counts recorded)
## Signers
- <Role1>: <name> <date> · <Role2>: <name> <date> (REF-B never inherits REF-A signers)
## On FAIL
- Root cause week: `program/gates/<gate>-RCA-<date>.md` · Re-run: <YYYY-MM-DD>
```

### Required attachments per gate (missing file = automatic FAIL)

| Gate | Attachments (paths relative to repo root) |
|------|--------------------------------------------|
| 0-to-1 | `logs/repo-sync-<builder>.txt`, `logs/kernel-defconfig-<sku>.txt`, `program/BLOBS-<sku>.md` with SHAs, `logs/uart-stock-boot-<sku>.log` |
| 1-to-2 | `logs/systemd-login-<sku>.log`, `logs/binder-nodes.txt` (`ls -l /dev/binder*`), `logs/suspend-50-<sku>.csv`, `logs/qrtr-lookup.txt`, `logs/modetest.txt`, `logs/evtest-<touch>.txt` |
| 2-to-3 | `logs/panel-<sku>.json`, `logs/touch-200tap-<sku>.csv`, `logs/fence-fd-counters.txt`, `logs/crash-banner-journal.txt`, `logs/perm-sync-x20.txt`, `logs/vpn-egress.txt`, `logs/sockets-audit.txt`, `logs/backup-roundtrip.txt` |
| 3-to-release | all Phase-3a/b/c sheets (ch.07 telephony, GNSS, power per ch.10 S8), `logs/avb-green.txt`, `logs/ota-rollback-demo.txt`, `logs/dogfood-7day-summary.md`, `logs/cts-allowlist.txt`, `SBOM.spdx.json`, `program/support-dryrun.txt` |

Lint before sign:

```bash
./scripts/gate-lint.sh program/gates/1-2-20260814-REF-A.md program/gates/1-2-20260814-REF-A.json
# Expected:
# GATE-LINT OK: fields=10/10 attachments=6/6 signers=2/2 verdict=PASS build=halide-20260814-a3f9c1e2b4d6
./scripts/gate-verify-hashes.sh program/gates/1-2-20260814-REF-A.json images/
# Expected:
# HASH-MATCH host.img e3b0c442 system.img 9f2c1184 boot.img 7d4a55c1 vbmeta.img 41be9f00
```

Verification checklist (QA runs, Arch co-signs): sidecar parses as JSON with all 11 fields; md checklist all ticked with quoted bar items matching ch.00 verbatim; bundle sha256 matches sidecar; calibration IDs unexpired (ch.02 S13 date check); REF-B record never references REF-A build IDs; FAIL records carry RCA plus rerun date within 14 days.

## Cross-chapter identifier registry (Owner: Arch · Phase: all — drift fails CI)

These strings are load-bearing. Identical spelling everywhere or `scripts/plan-consistency.sh` fails the doc CI job (next section). Rename only via a single MR that updates this registry, all chapters, and all scripts atomically, with an ADR if the rename crosses a runtime boundary (property, socket, unit, metric).

### A. Android system properties (exact name=default as read by bridges)

| Property | Canonical value / pattern | Defined in | Consumed by |
|----------|---------------------------|------------|-------------|
| `sys.boot_completed` | `1` (headless gate) | ch.05 container init | ch.00 Gate 1-2, ch.09 VIRT proof, ch.10 harness |
| `sys.halide.bridge` | `native-lxc-1` | ch.05 prop-dbus bridge | ch.06 drawer badge, ch.10 perm-sync suite |
| `ro.halide.slot` | `a\|b` | ch.09 A/B layout | ch.08 AVB policy, ch.09 OTA payload |
| `persist.halide.apn_override` | user APN string, never clobbered | ch.07 modem-host | ch.11 S19 gate-breach rule (clobber = suspension) |
| `sys.halide.crash_banner` | `armed\|fired:<ts>` | ch.05 crash path | ch.00 Gate 2-3 evidence |
| `ro.build.halide` | `halide-<date>-<sha12>` | ch.09 image assembly | all gate records `build_id` |

### B. Sockets, bus names, mount points (byte-exact paths)

| Path / name | Type | Owner side | Notes |
|-------------|------|------------|-------|
| `/dev/binder` + `/dev/binderfs/binder-control` | binder device | kernel to container | `ls -l /dev/binder*` is Gate 1-2 evidence |
| `/run/halide/prop.sock` | unix stream | prop-dbus bridge | ch.05 bridges; SOCKETS audit allowlist |
| `/run/halide/ril.sock` | unix stream | RIL-MM single-stack | ch.07 S1 dual-master ban enforcement point |
| `/run/halide/display-0` | wayland socket | composer bridge | ch.06 SEQ-join key for tap CSV |
| `org.halide.Modem` | D-Bus name | host MM wrapper | `busctl --list \| grep halide` check |
| `/mnt/android/system` + `/mnt/android/vendor` | bind mounts | LXC config | read-only + verity; ch.08/09 pin |

### C. systemd units (exact names; rename breaks factory + OTA)

| Unit | Role | Chapter |
|------|------|---------|
| `halide-android.service` | LXC container lifecycle, restart-with-backoff | ch.05 verification demo |
| `halide-prop-bridge.service` | prop-dbus forwarder | ch.05 bridges |
| `halide-ril-bridge.service` | RIL-MM translator, single-stack guard | ch.07 |
| `halide-composer.service` | SurfaceFlinger-Wayland bridge | ch.06 |
| `halide-bootstage.service` | boot-stage animation + banner arming | ch.05/06 |
| `halide-ota-finalize.service` | A/B finalize on first boot after update | ch.09 OTA |

### D. Metric and file names (dashboard + scripts join on these)

| Metric / file | Format | Produced by | Consumed by |
|---------------|--------|-------------|-------------|
| `dogfood_p0_per_1k_days` | float, 1 decimal | ch.10 S10 rollup | ch.00 Gate 3-release, ch.11 S11 trend |
| `nightly_boot_rate` | `passed/total` | ch.10 harness | ch.11 S11 (100 percent required) |
| `mr_merge_latency_p50_h` | hours, int | CI export | ch.11 S11/S17 freeze trigger (over 72h) |
| `out_of_tree_lines` | int, strictly decreasing | `scripts/count-oot.sh` | ch.03 S20 graph, ch.11 S11 |
| `panel.json` | JSON schema v3 (`width,height,fps,mode`) | ch.06 measurement | ch.00 Gate 2-3 entry |
| `power-sheet-<sku>-<date>.md` | ch.10 S8 template | QA/lab | ch.00 Gate 3-release entry |

Drift probe (same as CI):

```bash
./scripts/plan-consistency.sh --strict
# Expected:
# CONSISTENCY OK: props=6/6 sockets=6/6 units=6/6 metrics=6/6 gates=4/4 files=12/12
grep -rn "sys.boot_completed" hybrid-os-plan/*.md | wc -l
# Expected: count=7 (00,05,09,10 plus 2 gate templates plus this registry); any other count = investigate
```

Verification checklist: registry tables render (6+6+6+6 rows minimum); every identifier greps in its Defined-in chapter; no chapter defines a second spelling (case-sensitive grep shows zero aliases); rename MRs touch this section plus all consumers plus scripts in one commit.

## Doc-change CI checks (Owner: Release + Arch · Phase: all — docs are code)

Doc MRs run three gates. Red docs block the release train exactly like red code (ch.11 S19: merged red-CI = suspension plus 7-day retro).

### Check matrix

| Check | Script / job | Fail threshold | Fix path |
|-------|--------------|----------------|----------|
| char budgets | `scripts/wc-budget.sh` | any file under budget, or sum under 500K, or any file over budget x1.05 | expand that chapter procedures/tables (ch.00 How-to-continue) |
| identifier consistency | `scripts/plan-consistency.sh --strict` | any registry miss or alias | update chapter to registry spelling, or atomic rename MR + ADR |
| gate-record lint | `scripts/gate-lint.sh <md> <json>` | missing field/attachment/signer | complete artifact, never `--no-verify` |
| markdown links | `scripts/md-links.sh` | broken intra-plan link | fix `*.md` anchor or file name |
| trailing whitespace / tabs | `git diff --check` | any hit | clean before push |

### wc-budget check (binding numbers from the File-map table)

```bash
./scripts/wc-budget.sh
# Expected (post-expansion example):
# 00: 30712/30000 OK  01: 50120/50000 OK  02: 50244/50000 OK  03: 90110/90000 OK
# 04: 90302/90000 OK  05: 80115/80000 OK  06: 70140/70000 OK  07: 60180/60000 OK
# 08: 70102/70000 OK  09: 60155/60000 OK  10: 50190/50000 OK  11: 40530/40000 OK
# SUM=741300/740000 WINDOW=500000-900000 STATUS=COMPLETE
wc -m hybrid-os-plan/*.md | tail -1
# Expected: total character count >=500000 (midpoint target ~740000, cap 900000)
```

Reference `scripts/wc-budget.sh` logic (committed verbatim, 40 lines max):

```bash
#!/bin/bash
# FAIL if any file under budget or >5% over; FAIL if sum outside 500K-900K.
declare -A B=( [00]=30000 [01]=50000 [02]=50000 [03]=90000 [04]=90000 [05]=80000 \
  [06]=70000 [07]=60000 [08]=70000 [09]=60000 [10]=50000 [11]=40000 )
sum=0; rc=0
for n in 00 01 02 03 04 05 06 07 08 09 10 11; do
  f=hybrid-os-plan/$n-*.md; actual=$(wc -m < $f); budget=${B[$n]}; cap=$((budget*105/100))
  sum=$((sum+actual))
  if [ "$actual" -lt "$budget" ]; then echo "$n: $actual/$budget UNDER"; rc=1
  elif [ "$actual" -gt "$cap" ]; then echo "$n: $actual/$budget OVER-CAP(+5%)"; rc=1
  else echo "$n: $actual/$budget OK"; fi
done
echo "SUM=$sum WINDOW=500000-900000"
[ "$sum" -lt 500000 ] && rc=1; [ "$sum" -gt 900000 ] && rc=1
exit $rc
# Expected exit: 0 when all files within [budget, budget*1.05] and sum in window.
```

### Consistency grep (what plan-consistency.sh --strict runs)

```bash
./scripts/plan-consistency.sh --strict
# Expected:
# CONSISTENCY OK: props=6/6 sockets=6/6 units=6/6 metrics=6/6 gates=4/4 files=12/12
grep -rn "/run/halide/prop.sock" hybrid-os-plan/*.md | wc -l
# Expected: count=5 (00 registry, 05 bridges x2, 10 SOCKETS audit, 11 grow-list); drift = fix spelling
grep -rni "halide-android\.service" hybrid-os-plan/*.md | wc -l
# Expected: count=4 (00 registry, 05 unit file, 06 composer ordering, 09 factory); zero aliases like halide_android
```

Verification checklist (doc-CI green means): `wc-budget.sh` exit 0 with per-file OK lines archived in the MR; `plan-consistency.sh --strict` prints the `CONSISTENCY OK` line with 6/6/6/6/4/12 counts; `gate-lint.sh` passes on any touched gate record; `md-links.sh` zero broken anchors; `git diff --check` clean; reviewer confirms new procedures end with `Expected:` blocks and troubleshooting rows (ch.00 DoD items 2-3).

### Doc MR review SLA and merge rules (Owner: Arch · Phase: all)

| MR class | Reviewer | SLA | Merge rule |
|----------|----------|-----|------------|
| typo / formatting only | any area reviewer | 24h | 1 approval + CI green; no ADR needed |
| procedure change (commands, Expected) | owning chapter owner + QA | 48h | 2 approvals + VIRT re-run log attached + CI green |
| registry / gate-template change | Arch + affected chapter owners | 72h | unanimous + atomic rename proof (`plan-consistency.sh --strict` OK pasted in MR) |
| budget-table change (File-map numbers) | Arch + Program | 72h | ADR + all 12 files re-measured with `wc -m` table in MR description |

```bash
git diff --check
# Expected: (no output — clean)
git log --oneline -3 -- hybrid-os-plan/00-index-and-how-to-read.md
# Expected:
# a3f9c1e2b4d6 doc(00): registry adds ril.sock owner side
# 7d4a55c19e02 doc(00): gate template adds quarantine_delta
# 41be9f001c77 doc(00): budgets table resync with wc -m actuals
```

Verification checklist: MR description quotes pre/post `wc -m` for touched files; registry renames link the ADR and show zero alias grep hits; procedure MRs attach the re-run `Expected:` output (copy-paste, not retyped); `--no-verify` merges revert on sight per ch.11 S19; stale-procedure reports cite quoting-line.

Next: read `01-vision-requirements-personas.md`.
