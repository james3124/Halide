# 03 — Kernel (Mainline LTS + GKI), Modules & Bootloader
**Budget: 90,000 chars · Phases: 0–1 · Owner: Kernel/BSP · Target: 6.6 LTS (fallback 6.1) + GKI 2.0**

## 1. Principles

1. Mainline-first. No out-of-tree board files, no vendor fork as base. Vendor code arrives as DKMS-style modules or backported drivers with an upstreaming plan and a removal date.
2. One kernel binary per SoC family + signed GKI modules + DTB + DTBO. `uname -r` identical across slots; modules version-magic pinned.
3. Every Androidism is a config + test: `binder`, `ashmem`, `ion` (legacy shim where needed), `wakelock` (as `wakeup_source` audit), `SELinux`, `cgroup` (v2 with v1 compat for old userspace where AOSP demands).
4. Boot is measured: AVB vbmeta → boot.img → systemd → container. Every stage logs to pstore on failure.

## 2. Source layout & pins

```
~/hybrid/kernel/
  linux/            # mainline LTS checkout (tag v6.6.x, recorded in MANIFEST)
  gki/              # GKI fragment + vendor_module_list
  devices/<sku>/    # defconfig fragment + DT overlay + quirks
  out/<sku>/        # build artifacts (never committed)
MANIFEST.kernel     # exact tags + SHAs
```

Pin procedure:

```bash
cd ~/hybrid/kernel/linux && git fetch --tags
git checkout v6.6.30 && git rev-parse HEAD | tee ../MANIFEST.kernel
# Record toolchain: clang --version, gcc --version, rustc --version
```

Toolchain: LLVM/Clang matching GKI (currently clang-r498229 or newer per GKI release notes) + LTO=thin. Keep `BUILD_RBE` off for reproducibility v1; document container digest (`debian:bookworm` + pinned apt snapshot).

## 3. Defconfig (merge order matters)

```
defconfig order:
 1. arch/arm64/configs/defconfig
 2. gki_defconfig fragment (android/gki_defconfig from common)
 3. halide-base.fragment   # binder, ashmem, networking, DRM, USB, PM
 4. devices/<sku>/halide-<sku>.fragment
```

`halide-base.fragment` essentials (with rationale):

```
CONFIG_ANDROID=y
CONFIG_ANDROID_BINDER_IPC=y
CONFIG_ANDROID_BINDERFS=y
CONFIG_ASHMEM=y
CONFIG_SW_SYNC=y
CONFIG_SYNC_FILE=y
CONFIG_DMA_SHARED_BUFFER=y
CONFIG_DMABUF_HEAPS=y
CONFIG_DMABUF_HEAPS_SYSTEM=y
CONFIG_DMABUF_HEAPS_CMA=y
CONFIG_CGROUPS=y
CONFIG_MEMCG=y
CONFIG_CGROUP_SCHED=y
CONFIG_CGROUP_PIDS=y
CONFIG_CGROUP_FREEZER=y
CONFIG_CGROUP_DEVICE=y
CONFIG_CPUSETS=y
CONFIG_SECCOMP=y
CONFIG_SECCOMP_FILTER=y
CONFIG_SECURITY_SELINUX=y
CONFIG_SECURITY_SELINUX_BOOTPARAM=y
CONFIG_DEFAULT_SECURITY_SELINUX=y
CONFIG_DRM=y
CONFIG_DRM_MSM=y
CONFIG_DRM_PANEL=y
CONFIG_BACKLIGHT_CLASS_DEVICE=y
CONFIG_INPUT_TOUCHSCREEN=y
CONFIG_SND_SOC=y
CONFIG_SND_SOC_QCOM=y
CONFIG_USB_DWC3=y
CONFIG_USB_DWC3_QCOM=y
CONFIG_RPMSG_QCOM_GLINK_RPM=y
CONFIG_QRTR=y
CONFIG_QRTR_SMD=y
CONFIG_RMNET=y
CONFIG_QMI_HELPERS=y
CONFIG_PM_SLEEP=y
CONFIG_SUSPEND=y
CONFIG_PM_WAKELOCKS=y
CONFIG_RTC_DRV_PM8XXX=y
CONFIG_IIO=y
CONFIG_QCOM_SPMI_ADC5=y
CONFIG_REGULATOR_QCOM_RPMH=y
CONFIG_PINCTRL_MSM=y
CONFIG_ARM_SMMU=y
CONFIG_PCIE_QCOM=y
CONFIG_UFS_QCOM=y
CONFIG_MMC_SDHCI_MSM=y
CONFIG_PSTORE=y
CONFIG_PSTORE_RAM=y
CONFIG_RAMOOPS=y
```

Verification: `scripts/diffconfig .config.old .config` shows only intended deltas; `make savedefconfig` diff committed.

## 4. GKI module strategy

- In-tree where accepted (display, pinctrl, interconnect). Out-of-tree only for: camera CAMSS deltas, audio machine quirks, touch firmware loaders — each as `vendor_modules/<name>/` with `Kbuild`, `dkms.conf` equivalent, and `UPSTREAMING.md` (link to lore thread or TODO with date).
- Sign all modules with release key in ch.09; dev builds use test key with `CONFIG_MODULE_SIG_FORCE` off, release on.
- `depmod` + `modules.order` generated at image build, not on device first boot (deterministic boot time).

## 5. Device tree

- Fork nothing: overlay per SKU in `devices/<sku>/dts/`. Example overlay snippet for panel:

```dts
/dts-v1/; /plugin/;
&mdss_mdp { status = "okay"; };
&mdss_dsi0 {
  status = "okay";
  panel@0 {
    compatible = "halide,<panel>-v1";
    reg = <0>;
    vddio-supply = <&vreg_l14a>;
    backlight = <&pmi8998_wled>;
    port { panel_in: endpoint { remote-endpoint = <&dsi0_out>; }; };
  };
};
```

- Validate: `dtc -I dts -O dtb`, `fdtdump`, boot with `fdt rm` fault-injection test (missing panel → graceful framebuffer fallback, not panic).
- Commit `dtb` disassembly diff per release for review.

## 6. Boot image & AVB

Layout (A/B): `boot_a/boot_b` (GKI + ramdisk), `vendor_boot`, `vbmeta_a/b`, `dtbo`, `super` (system/vendor/product partitions), `userdata`.

```bash
# Build boot.img (example sizes — adjust per SKU flash map)
mkbootimg.py --kernel out/<sku>/arch/arm64/boot/Image.gz \
  --ramdisk out/<sku>/ramdisk.cpio.gz --dtb out/<sku>/dtb \
  --pagesize 4096 --base 0x80000000 \
  --cmdline "console=ttyMSM0,115200n8 androidboot.hardware=qcom androidboot.memcg=1 cgroup.memory=nokmem printk.devkmsg=on" \
  -o out/<sku>/boot.img
# Sign with AVB
avbtool add_hash_footer --image out/<sku>/boot.img --partition_name boot --partition_size 67108864
avbtool make_vbmeta_image --output out/<sku>/vbmeta.img --key keys/release.key --algorithm SHA256_RSA4096 --flag 2 \
  --include_descriptors_from_image out/<sku>/boot.img
```

Dev vs release: `--flag 0` (verified boot off, orange state) for bring-up; `--flag 2` (enforcing) required for Phase-3 gate.

Rollback: increment `--rollback_index` per release; test rollback rejection explicitly (flash old image → must refuse to boot with event logged).

## 7. Ramdisk & early userspace

Two-stage ramdisk: (a) GKI first-stage (mount, verity setup), (b) HALIDE second-stage that pivots to systemd on `super`. Include: `busybox`, `lvm`/`dm` tools, `avb`, `pstore` collector, `uart-shell` fallback (passwordless only in `eng` builds, never release).

Boot stages + timeouts: firmware→ABL ≤8s, kernel→systemd ≤12s, systemd→login ≤15s, container→boot_completed ≤120s (Phase 3: ≤60s). Watchdog pet from systemd; missed pet → ramoops + reboot with reason.

## 8. Power/suspend bring-up sequence

1. `mem_sleep` = `deep`; verify `cat /sys/power/mem_sleep` → `[deep] s2idle`.
2. Wakeup sources audit: `cat /sys/kernel/debug/wakeup_sources` sorted; no `qcom-step-wifi` storm (>100/s blocks gate).
3. Modem suspend: QRTR杳 idle, `rmnet` down, USB autosuspend on; measure with power meter (idle target per ch.02 envelope).
4. Display off + touch wake only on defined gesture; no full SoC wake on finger hover.

## 9. Debug & failure capture

- Always: `pstore` (console-ramoops + dmesg-ramoops + ftrace-ramoops), `ramoops.mem_address` from SKU memory map, `printk.always_kmsg_dump`.
- Crash triage: `cat /sys/fs/pstore/console-ramoops-0`, `dmesg -T`, `journalctl -b -1`, `logcat -b all -d` (once container up).
- Bisect runbook: `git bisect` with `defconfig+dtb`-only test (UART prompt = pass) before full Android test.

## 10. Common failures table

| Symptom | Log | Fix |
|---------|-----|-----|
| Fastboot boot loops to EDL | ABL log, `fastboot getvar` | DTB load address overlap; check `boot.img` header vs flash map |
| `binder: BINDER_SET_CONTEXT_MGR failed` | dmesg | binderfs not mounted; add `binderfs` mount unit before container |
| Black screen, UART alive | `dmesg \| grep -i drm/panel` | DSI timings or regulator; try simple-panel + fixed regulator to isolate |
| Modem invisible (`/dev/cdc-wdm0` missing) | `dmesg \| grep -i qrtr/rmnet` | missing `QRTR_SMD` or firmware; check `rproc` state |
| Suspend resumes instantly | wakeup_sources | disable touch wake, re-audit; check charger/USB wake |
| AVB red state, won't boot release | `avbtool info_image` | rollback index or key mismatch; re-sign full chain |

## 11. Full kernel build runbook (reproducible, containerized)

Builder image digest is pinned in `ci/Dockerfile` (example `debian:bookworm-20260210-slim`, SHA recorded in MANIFEST). Never build on a dirty host.

```bash
set -euo pipefail
SKU=${1:-sdm845-oneplus6}
J=$(nproc)
K=~/hybrid/kernel; OUT=$K/out/$SKU
mkdir -p "$OUT"
cd $K/linux
# 1. pristine check
git status --porcelain | tee $OUT/git-status.txt; test ! -s $OUT/git-status.txt
git rev-parse HEAD | tee $OUT/git-sha.txt
# 2. merge defconfig in order (order matters — later fragments override)
make ARCH=arm64 O="$OUT" defconfig
scripts/kconfig/merge_config.sh -m -O "$OUT" \
  "$OUT/.config" \
  $K/gki/android_gki.fragment \
  $K/halide-base.fragment \
  $K/devices/$SKU/halide-$SKU.fragment
make ARCH=arm64 O="$OUT" savedefconfig
cp "$OUT/defconfig" "$OUT/defconfig.merged"
# 3. build (clang + thinLTO per GKI notes)
make ARCH=arm64 O="$OUT" -j$J \
  CC=clang LD=ld.lld LLVM=1 LLVM_IAS=1 \
  Image.gz modules dtbs 2>&1 | tee $OUT/build.log
# 4. modules install into staging (deterministic depmod)
make ARCH=arm64 O="$OUT" INSTALL_MOD_PATH="$OUT/modules-staging" modules_install
depmod -b "$OUT/modules-staging" -F "$OUT/System.map" $(make ARCH=arm64 O="$OUT" -s kernelrelease)
# 5. record artifacts
sha256sum $OUT/arch/arm64/boot/Image.gz | tee $OUT/SHA256.txt
find $OUT/modules-staging -name '*.ko' | sort | xargs sha256sum >> $OUT/SHA256.txt
zcat /proc/config.gz 2>/dev/null | diff - <(zcat $OUT/config.gz 2>/dev/null) || true
echo "BUILD OK: $(date -u +%FT%TZ) clang $(clang --version | head -1)" | tee -a $OUT/SHA256.txt
```

Expected: `Image.gz` + `*.ko` + `*.dtb` present; `SHA256.txt` committed per release. Two builders with the same container digest must produce identical `Image.gz` bytes (modulo embedded build timestamp — set `KBUILD_BUILD_TIMESTAMP` from MANIFEST to make it bit-identical; document the value).

Repro tip: export `SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)` and `KBUILD_BUILD_USER=halide KBUILD_BUILD_HOST=repro` before make. Verify with `diffoscope` on the two `Image.gz` files quarterly; any unexplained delta is a P1 build-infra bug.

## 12. Kconfig rationale table (why each Androidism exists)

| Symbol | Why HALIDE needs it | If disabled, what breaks | Test |
|--------|---------------------|--------------------------|------|
| `ANDROID_BINDER_IPC` + `BINDERFS` | Android services + per-container binder mounts | `ServiceManager` never registers; `sys.boot_completed` never 1 | `ls /dev/binderfs/binder*`; `binderfs_test` |
| `ASHMEM` | legacy gralloc/ashmem users (camera, dalvik) | camera green frames / app crashes in old NDK paths | `ashmem_test` from AOSP bionic tests |
| `SW_SYNC` + `SYNC_FILE` | explicit fencing for composer bridge | tearing / composer timeout (ch.06) | `sync_test`; fence timeout counter stays 0 |
| `DMABUF_HEAPS` (+SYSTEM/CMA) | dma-buf import SurfaceFlinger→Wayland | black Android windows | `dmabuf-heap-test`; `halide-composer --debug` imports |
| `CGROUP_*` (pids/freezer/devices/cpuset) | LXC + Android lowmemorykillerd successor (lmkd) | container OOM kills host processes | `lxc-checkconfig`; lmkd props set |
| `SECCOMP_FILTER` | app sandbox both stacks | CTS `CtsSeccompTestCases` fail | run CTS seccomp subset |
| `SELINUX` + BOOTPARAM + DEFAULT | Android MAC enforcing | `getenforce` Permissive blocks Phase-3 gate | `getenforce` → Enforcing in both namespaces |
| `DRM_MSM` | Adreno display | no `/dev/dri/card0`; Phosh falls to software | `modetest -M msm` lists connector |
| `QRTR` + `QRTR_SMD` + `QMI_HELPERS` + `RMNET` | modem control + data | `/dev/cdc-wdm0` missing; no LTE (ch.07) | `qrtr-lookup`; `qmicli --dms-get-ids` |
| `RPMSG_QCOM_GLINK_RPM` + `RPMH` regulators | power domains + clock votes | random hangs under load; sensors dead | `pm_genpd_summary` shows domains |
| `PINCTRL_MSM` | every peripheral mux | UART/I2C/SPI silent death | `cat /sys/kernel/debug/pinctrl/.../pinmux-pins` |
| `ARM_SMMU` | display/camera/modem IOMMU isolation | faults under camera+display concurrency | `dmesg \| grep -i smmu` clean under stress |
| `UFS_QCOM` + `SDHCI_MSM` | storage | no root mount | `lsblk`; `dmesg \| grep -i ufshcd` link up |
| `PSTORE` + `RAMOOPS` | post-crash forensics | crashes without logs = undebuggable gate fail | forced `sysrq-c` (eng) leaves ramoops |
| `PM_WAKELOCKS` (as audit) | translate Android wakelocks to `wakeup_source` | power regressions invisible | `wakeup_sources` audit script passes |

cgroup note: AOSP 14 userspace expects cgroup v2 with specific controllers; keep `systemd.unified_cgroup_hierarchy=1` on host and mount v1 compat (`cgroup.memory=nokmem` legacy quirk only where AOSP `lmkd` demands — document exact prop).

## 13. Device-tree per-subsystem checklist (REF-A SDM845 shape)

 regulators: `rpmh-regulator` nodes (`vreg_l14a` etc.) with `regulator-min/max-microvolt`, `regulator-always-on` only where stock proves required. Mistake pattern: marking everything always-on hides a missing vote and doubles idle power — audit with `regulator_summary` + current meter.
 pinctrl: one state per peripheral (`default` + `sleep`); verify `sleep` actually lowers current (measure, don't assume).
 llcc/system-cache: keep stock cache partitioning for display/camera; wrong slice = underruns at 60fps.
 interconnect (`icc`): display + camera + modem paths need bandwidth votes; test with concurrent camera preview + display + iperf (ch.10 perf gate).
 rproc (adsp/cdsp/mpss): firmware paths (`qcom/sdm845/*.mbn`) + `rproc` state machine; `cat /sys/class/remoteproc/remoteproc*/state` → `running` for audio/modem DSPs. Missing PAS auth = silent DSP death — log `qcom_q6v5_pas` probe explicitly.
 pmi8998 pon/resin: volume-down+power hard-reset must always work (safety); test quarterly.
 wled/backlight: PWM period + max brightness matched to panel datasheet; wrong period = flicker at low brightness (camera-visible test with 240fps phone camera).
 touch: I2C address + IRQ GPIO + `touchscreen-size-x/y` + firmware filename; multitouch slots verified with `evtest` 10-finger.
 battery/gauge: `qcom-spmi` ADC channels + gauge IC (`max17040`-class) calibration; report full-charge-capacity vs design capacity in `hw/<sku>/battery.md`.
 NFC (if present): NCI over I2C/UART; v1 informational (not a gate) — record present/absent.

DT review rule: every overlay line has a comment with source (stock DT dump, datasheet page, or measured). Lines without provenance are rejected in review.

## 14. Modem/QRTR bring-up detail (host side, before Android RIL)

```bash
# rproc + qrtr namespace
cat /sys/class/remoteproc/remoteproc*/state   # expect running (mpss)
qrtr-lookup                                    # expect NS + services
ls -l /dev/cdc-wdm* /dev/wwan* 2>&1 | tee logs/qrtr-nodes.txt
qmicli -d /dev/cdc-wdm0 --dms-get-ids --device-open-qmi
qmicli -d /dev/cdc-wdm0 --nas-get-signal-strength
qmicli -d /dev/cdc-wdm0 --nas-get-system-selection-preference
```

Failure ladder: no `cdc-wdm` → check `qmi_wwan`/`rmnet` probe + firmware (`dmesg | grep -i -e qrtr -e rproc -e qmi`); `qmicli` timeout → QRTR routing (`qrtr-ns` running?); signal 0 → antenna/RF path or SIM (try second SIM + `mmcli -i` state). Record `qrtr-lookup` output per release — service list drift means firmware changed.

## 15. USB/OTG, SD, PCIe (secondary but gate-adjacent)

- `dwc3-qcom` dual-role: host (ADB from phone to PC) + device (ADB to phone, MTP). Role-switch via `extcon`+gotested with C-to-C and C-to-A cables (both orientations — orientation bugs are real).
- UFS: record gear/pwm state (`/sys/kernel/debug/ufshcd*/stats`); enable `clkscale` + `hibern8` for idle power; verify no link errors after 24h (`err_stats` stays 0).
- SD (if slot): `sdhci-msm` DDR50/SDR104 per card; never use SD as adoptable storage v1 (document why: wear + encryption complexity).

## 16. Sensors/IIO/GNSS host plumbing

`sensors` HAL consumes IIO; verify each sensor at host first: `iio_info | grep -A3 accel`, `cat /sys/bus/iio/devices/iio:device*/in_accel_*_raw` changes on tilt. Magnetometer needs factory cal blob path documented (or heading wrong — record bias procedure). Barometer/ALS/proximity: thresholds in DT (`proximity-near-level`); test with finger + lux meter app. GNSS: modem PDS over QMI; host `gpsd` or direct QMI PDS client; NMEA to `/run/halide/gnss.nmea` for both Phosh Maps and Android `IGnss` shim.

## 17. Early-debug toolbox (keep in ramdisk + host)

`kgdboc` over UART (`kgdboc=ttyMSM0,115200 kgdbwait` in eng only), `ftrace` function_graph for suspend path (`echo function_graph > current_tracer; echo 1 > tracing_on` around `echo mem > /sys/power/state`), `dynamic_debug` for `drm`, `qrtr`, `rmnet` (`echo 'module drm +p' > dynamic_debug/control`), `kdump`/`kexec` where memory map allows (fallback: ramoops). `perf stat -e power/energy-pkg/` where PMU exposes it (else external meter is truth).

Suspend debug script (commit as `scripts/suspend-stress.sh`):

```bash
#!/bin/bash
# 50-cycle suspend/resume with wakeup audit
for i in $(seq 1 50); do
  echo "cycle $i $(date -u +%FT%TZ)" | tee -a logs/suspend.txt
  cat /sys/kernel/debug/wakeup_sources | sort -k7 -n -r | head -5 | tee -a logs/suspend.txt
  rtcwake -m mem -s 10 || echo "RESUME-FAIL cycle $i" | tee -a logs/suspend.txt
  dmesg | tail -20 | tee -a logs/suspend.txt
done
grep -c RESUME-FAIL logs/suspend.txt || echo "0 failures"
```

Gate: 0 failures + no new wakeup-source storm vs baseline.

## 18. ABL/fastboot customization & EDL safety

Keep stock ABL where possible; HALIDE changes limited to: boot logic for slots (A/B metadata in `misc`), `fastboot oem halide-logs` (exports pstore over fastboot), unlock flow preserving persist/EFS backup prompt. EDL (9008) is the last resort — document per-SKU entry (test point photo or button combo) in `hw/<sku>/edl.md` with the warning that EDL flashing without backup can brick calibration. `fastboot getvar all` output archived per release (bootloader version drift detection).

Flash map example (`images/<sku>/flashmap.json` — sizes are SKU-specific, never generic):

```json
{"partition_boot_a_size": 67108864, "partition_vendor_boot_size": 67108864,
 "partition_vbmeta_size": 8388608, "partition_dtbo_size": 8388608,
 "partition_super_size": 9663676416, "slot": "a/b", "userdata": "remaining"}
```

`fastboot flash` wrapper validates image sizes against this file before touching the device (refuse on mismatch — prevents cross-SKU bricks).

## 19. Watchdog, hard-reset, watchdog-vs-debug policy

Hardware watchdog (`qcom-wdt`) petted by systemd (`RuntimeWatchdogSec=30s`); eng builds allow `nowatchdog` cmdline for kgdb sessions (release forbids it — CI greps cmdline). Resin (volume-down+power 10s) must hard-reset even with kernel hung (test with `echo c > /proc/sysrq-trigger` + resin — device must reboot; if not, PMIC config wrong, P0 bug).

## 20. Upstreaming & tech-debt ledger

Every out-of-tree file lists: upstream status (`posted v3 to lore <link>` / `needs rework: <reason>` / `no upstream path — vendor NDA blob wrapper, removal blocked by X`), owner, and quarterly review date. Ledger in `kernel/TECH-DEBT.md`; release blocked if any entry is past review date without update. Goal: out-of-tree line count strictly decreases each release (graph in release notes).

## 21. Bisect automation (`scripts/kernel-bisect.sh` — regressions get bisected, not debated)

Wrapper around `git bisect` with HALIDE pass/fail definitions per subsystem (UART prompt = boot-pass; `modetest` connector = display-pass; `qrtr-lookup` non-empty = modem-pass; 5-cycle suspend = power-pass): `./scripts/kernel-bisect.sh --good v6.6.20 --bad v6.6.30 --test modem` checks out, builds (ccache-hot, defconfig+dtbs+Image only — 4-min iterations, not full-image), fastboot-boots sacrificial unit, runs the subsystem probe, reports. Bisect runs unattended overnight with serial logging per iteration (`logs/bisect/<date>/b<N>-dmesg.txt`); morning delivers culprit commit + first-bad-behavior diff. Rule: any kernel-stable bump that regresses a gate gets bisected within 72h (before the "maybe it's flaky" narrative hardens — ch.10 §11 flake-triage clock applies here too). Culprit handling: revert-and-report-upstream (stable@ + lore, with our probe as reproducer) vs carry-patch with `UPSTREAMING.md` entry (ch.03 §20 ledger — no silent carries).

## 22. Upstream CI & lore hygiene (mainline-first is a practice, not a slogan)

Each out-of-tree patch series has: lore thread link, `Reviewed-by`/`Tested-by` status, rebase date vs latest LTS, and CI job `upstream-status` (weekly: `git fetch` + `git cherry` to detect upstreamed-commits — upstreamed patches auto-drop from our tree with a congratulations note in standup). `checkpatch.pl --strict` + `sparse` + `coccinelle` (project smPL set: lock-missing, `__user` annotation, DT `status` typos) run per MR touching kernel code. New-driver checklist before first commit: compiles with `W=1` zero-new-warnings, DT binding YAML in-tree (`Documentation/devicetree/bindings/...`, `dtbs_check` green), no `printk` without `dev_` prefix, power-management callbacks present-or-explained (a driver without suspend hooks on a phone is a power bug pre-installed).

## 23. KUnit & config-fuzz (unit tests for the layer that can't "just restart")

KUnit suites required for every new in-tree driver we carry (touch, panel, gauge, pinctrl-quirks): probe-success/fail paths (missing IRQ → `-EPROBE_DEFER`, not oops), suspend/resume callbacks (balanced `pm_runtime` gets/puts asserted), DT-parse of malformed properties (wrong `#cells` → graceful `-EINVAL`). Suites run in CI via `tools/testing/kunit/kunit.py run --arch=arm64` on the defconfig+fragment combo (ch.03 §11 build produces the same `.config` CI tests — no separate test-config drift). New driver without KUnit = review fail (ch.03 §22 checklist cites this section).

`CONFIG_FUZZ` harness for our DT-overlay parser path + `binderfs` mount-option parsing (syzkaller descriptions committed in `kernel/syzkaller/`): nightly 30-min syzkaller run on VIRT-arm64 with our fragment (corpus in repo, crashers auto-filed with `syzbot`-style reproducers). Syzkaller finding in carried code: fix-or-revert within the §15-equivalent 30-day clock (kernel bugs get CVE bins too — same bins, ch.08 §15 intake includes syzkaller source).

## 24. Release kernel signing & module provenance (the kernel half of the ceremony)

`Image.gz` + all `.ko` signed on the offline signer (ch.09 §15 ceremony handles transport; this section defines kernel-side inputs): `scripts/sign-kernel.sh --key $HSM_KERNEL_KEY --out signed-kernel/` signs Image (PE/COFF-adjacent `vmlinuz` signature envelope where bootloader verifies — per-SKU verify method in appendix-08A/B: some ABLs verify boot.img hash only (AVB covers), others verify kernel signature directly — both paths tested, the applicable one marked AUTHORITATIVE per SKU so testers don't chase the wrong check) + every module (`scripts/sign-file sha512 $KEY cert.x509 module.ko` in depmod order — order logged, unsigned-module-in-tree fails the script with the filename). `modules.order` + `modules.dep` regenerated post-sign (depmod after signing — pre-sign depmod artifacts are build outputs, post-sign are release artifacts; mixing them invalidates the signature chain and the script refuses when timestamps invert). Release kernel provenance file (`kernel-out/<sku>/PROVENANCE.txt` shipped in transparency repo, ch.09 §17): source SHA + fragment SHAs + toolchain versions + `KBUILD_BUILD_TIMESTAMP` value + signer key-id + `vermagic` string — `modinfo` on-device compared against PROVENANCE in factory smoke (factory §16 station runs the check; mismatch halts the line).

## 25. Kernel CI pipeline detail (every commit boots or it doesn't merge)

Pipeline stages (`ci/kernel-pipeline.yml`, all containerized per §11 digest pin): (1) `provenance` (MANIFEST.kernel SHA + fragment SHAs + toolchain versions recorded; dirty-tree builds rejected except `allow-dirty` bisect jobs §21 which are labeled NON-RELEASE), (2) `lint` (`checkpatch.pl --strict` + `sparse` + project coccinelle + `dtbs_check` on overlays — §22 bar, 10-min budget), (3) `build-matrix` (REF-A + REF-B fragments × `defconfig-merge-order-check`: job re-merges fragments in documented order §3 and diffs against committed `defconfig.merged` — order drift fails fast), (4) `kunit` (§23 suites, arm64, same `.config` — config-drift between build and test jobs fails the run), (5) `boot-smoke-VIRT` (QEMU arm64 `virt`: UART prompt + `/dev/binderfs` + DRM `virtio-gpu` probe — 15-min budget), (6) `boot-hw-sacrificial` (nightly + per-MR on demand: fastboot-boot REF-A sacrificial, probes §21 subsystem pass/fail set), (7) `suspend-10` (short suspend stress on HW: 10 cycles `rtcwake -m mem -s 10` + wakeup audit — full 50-cycle §17 weekly), (8) `artifacts` (`Image.gz` + modules + dtbs + SHA256.txt + PROVENANCE.txt §24 staged to release store; unsigned artifacts labeled ENG, signed only via §24 ceremony).

Budgets & flakes: per-MR pipeline target ≤45 min to VIRT-green (HW stages async, report back to MR — MRs don't block on sacrificial-unit queue depth, but merge requires last HW-green ≤7 days on the base commit). Flake policy: infra flakes (fastboot timeout, lab power blip) retried once with `INFRA-FLAKE` label + runner log link; test flakes follow ch.10 §11 triage clock (quarantine + BUG, never silent retry-to-green — retry-without-bug is a CI P1). Bisect-on-red: any `boot-hw` regression on main triggers automatic §21 bisect job within 24h (good = last-green SHA, bad = first-red SHA, test = failed subsystem) — results posted to the breaking MR.

Required secrets/permissions: CI fastboot runners hold no release keys (§24 offline signer is air-gapped from CI — CI produces ENG-signed artifacts only); HW-runner access logged per flash (feeds `hw/flash-log.csv` §11 automatically with `operator=ci-runner-N`).

## 26. Stable-bump cadence ops (LTS moves monthly — we move deliberately, not late)

Cadence: track mainline LTS monthly bumps (6.6.x → 6.6.y) on a fixed train: Week 1 (bump PR: tag + SHA into MANIFEST.kernel, `git log v6.6.x..v6.6.y --oneline` triaged into `kernel/STABLE-TRIAGE-<ver>.md` with per-commit relevance: `display/`, `mm/`, `net/`, `arm64/`, `qcom/` flagged for HW attention, the rest informational), Week 2 (CI full + 50-cycle suspend §17 + modem ladder §14 + composer smoke ch.06 §10 subset on sacrificial REF-A), Week 3 (dogfood nightly inclusion — bump rides nightly per ch.04 §18 step-6 pattern extended to kernel), Week 4 (release-train merge + rollback-index note if AVB-relevant). Skip rule: a bump with zero relevant-subsystem commits may fast-track (Week 1→4 with Arch + QA sign, triage file still required — "nothing relevant" is a claim with evidence, the triage file).

CVE fast-lane: kernel CVE affecting our config (ch.08 §15 bins intake includes stable-fixes) jumps the queue: out-of-band bump PR within SLA (Critical ≤7d, High ≤14d per ch.08 policy), minimum validation (CI + boot-hw + suspend-10 + affected-subsystem probes), dogfood 48h, ship as patch release (versioning ch.01 §13 patch bump). Fast-lane merges require Security + Kernel sign (§19-equivalent pair) and a post-ship full-validation ticket (debt with a date, not a shortcut forgotten).

Revert policy: if a stable bump regresses a gate and §21 bisect fingers an upstream stable commit within 72h, default is revert-and-report-upstream (carry-patch §20 entry only if revert breaks a CVE fix — both bad options documented in the MR with Security adjudicating). LTS EOL watch: 6.6 EOL announcement → migration plan (6.12 LTS candidate evaluation: GKI compatibility + SoC driver status + 4-week bring-up spike) within 30 days; running an EOL LTS without a plan is a Security P0.

## 27. Out-of-tree patch review bar (carried code earns its keep quarterly or leaves)

Admission checklist (new out-of-tree file or hunk, reviewer enforces — §20 ledger entry created same MR): (1) why-in-tree-impossible (upstream thread link showing rejection/deferral, or NDA-blob-wrapper justification with blocker named), (2) KUnit coverage (§23 — probe/fail/suspend paths, CI job linked), (3) `checkpatch --strict` + `W=1` clean + `dtbs_check` if DT-touching, (4) power note (suspend callback present or `NO-SUSPEND-IMPACT:` rationale with measurement — phone drivers without power reasoning don't merge), (5) removal condition (upstream version that obsoletes it, or date + owner for re-evaluation — entries without removal conditions are rejected, not "accepted with TODO"), (6) second-SKU impact (REF-B behavior stated: works / N/A-with-reason / UNTESTED-with-ticket — silent single-SKU carries rot the other port).

Review quorum: Kernel owner + affected-subsystem reviewer (display/modem/power) + Security if the code parses untrusted input (DT blobs, firmware headers, binder-adjacent ioctl — fuzz harness §23 extended to the new parser before merge). Size discipline: out-of-tree line-count graph (§20) reviewed per release — net-new carries need Arch exception (the trend must decrease; exceptions name the compensating removal).

Quarterly carry review (calendar invite, not aspiration): every §20 ledger entry older than 90 days presented in 5 min (upstream status delta since last review, rebase pain, removal forecast). Outcomes: DROP (upstreamed — §22 auto-detect confirms + celebratory standup note), REBASE (still needed, fresh lore ping sent that week with link), REWRITE-FOR-UPSTREAM (rework identified — owner + 30-day checkpoint), CONTAIN (NDA-blocked — re-justified with blocker status, sunset re-examined). Missed review = release blocker (§20 rule restated as calendar hygiene: the ledger review meeting moving twice consecutively escalates to Program).

## 28. Boot-time optimization log (fast boots are measured, not hoped)

Budget table (Phase-3 targets from §7 decomposed — every millisecond has an owner): firmware→ABL ≤8s (bootloader owner), kernel→systemd ≤12s (kernel: `initcall_debug` ranked — top-10 initcalls listed per release, any new entry >200ms flagged), systemd→login ≤15s (platform: `systemd-analyze blame` top-15 + `critical-chain`, per-unit budget in `boot/<sku>/unit-budgets.txt`), container→boot_completed ≤60s Phase-3 (Android: `bootchart`-equivalent + `logcat -b events` `boot_progress_*` timestamps). Total ≤45s cold-boot-to-lock (§5 DoD) with 5s contingency held by Program (spending contingency requires gate-review note).

Instrumentation (always-on, cheap): `printk.time=1` + `initcall_debug` (eng; release keeps `printk.time` only — overhead documented), `systemd-analyze plot > boot/<sku>/plot-<ver>.svg` per release (committed, diffable), `halide-boot-timeline` tool (merges dmesg + journal + logcat `boot_progress` into one CSV: `stage,ts_ms,source` — the single timeline everyone argues from instead of three clocks). Regression rule: any MR adding >500ms to any stage median (5-boot median on sacrificial REF-A, same charger/cable/ambient note per power-calibration honesty ch.10 §8) must carry the timeline CSV + justification or CI `boot-budget-check` fails the MR.

Optimization ledger (`boot/<sku>/OPT-LOG.md`, newest-first — the institutional memory of "we tried that"): deferred-init moves (probe-defer lists with before/after medians), module-load parallelization (`modules-load.d` ordering with measured wins), first-stage ramdisk trims (removed tool + size + time deltas), LZ4-vs-gzip ramdisk tradeoff per SKU (measured, not assumed — decompression speed vs flash size with both numbers), `readahead`/erofs tuning for container rootfs (cold-cache `boot_completed` medians). Anti-patterns banned with prejudice (each learned once, written down): blocking network in `halide-android-prepare` (modem FW download retries stall boot — async with timeout + degraded banner instead), `udev` settle-all (scoped waits per §2 `Requires=` device units, never blanket settle), DTOVERLAY probing every panel variant sequentially (ID-read once, select JSON per ch.06 §11 — probe-all costs seconds).

## 29. Initcall/boot-chart triage runbook (ranked slowness dies first)

Capture set per release (sacrificial REF-A, same cable/charger/ambient note per ch.10 §8): `dmesg` with `initcall_debug` (eng) → `scripts/initcall-rank.py` (parses `initcall <fn> returned 0 after <us>` lines into ranked table + flame-adjacent bar chart committed as `boot/<sku>/initcalls-<ver>.txt`), `systemd-analyze blame` + `critical-chain` + `plot.svg` (§28 set), container `boot_progress_*` event deltas (ch.04 §5 `logcat -b events` slice). Triage order is fixed (argue from the ranking, not from hunches): slowest initcall first (driver probe or deferred-work that should have been async — `async_probe` conversion with before/after medians), then systemd critical-chain head (the one unit everything waits on — usually a device-wait or bridge-prepare doing synchronous I/O, fixed by scoping the wait per ch.05 §18(a) not by lengthening timeouts), then container tail (HAL service registration gaps in `logcat` — missing-service stalls triaged via ch.04 §7 table before kernel blame).

Async/defer rules (the only legal moves): probe functions that hit sleeping hardware (firmware load, regulator settle, touch FW handshake) must be async or deferred (`probe_type`/`deferred_probe_timeout` with comment citing the measured stall — sync sleeps in probe are review fails); userspace waits must name a device unit (`Requires=sys-devices-...` style) rather than `sleep N` in scripts (every `sleep` in a boot-path script carries a `WHY-NOT-EVENT:` comment or CI `boot-lint` fails it); network-in-boot-path banned (§28 anti-pattern restated with enforcement — `halide-android-prepare` network calls run with `--timeout 5` + degraded-banner fallback, verified by unplugged-boot test: SIM-out + Wi-Fi-dead boot must still reach lock screen within budget +10s).

Weekly boot-trend job (CI HW nightly tail): 5-boot medians per stage plotted over time (`boot/<sku>/TREND.csv` → dashboard; >500ms week-over-week regression pages the stage owner per §28 rule — the page includes the ranked diff so the owner starts from evidence). Cold-vs-warm discipline: budget numbers are cold-boot (power-off ≥60s, flash cold — warm-cache boots measured separately and labeled `warm`, never averaged into cold medians to flatter the trend).

## 30. Ramoops/pstore sizing & verification (crash logs that survive the crash)

Sizing per variant (DRAM-size fork §19 ch.02 companion — addresses recomputed per RAM size, never copied): `ramoops.mem_address` in a DRAM region preserved across warm reset but outside kernel `memblock` + CMA + modem-shared carveouts (verify with `/proc/iomem` dump committed per variant: ramoops range marked `reserved`, zero overlap with `System RAM` executable regions); sizes (`record_size 0x20000` console + `0x20000` dmesg + `0x10000` ftrace + `0x10000` pmsg minimum — full `dmesg` of a modem-active boot exceeds 128KB, undersized record_size silently truncates the frames that matter). DT binding (`reserved-memory/ramoops` node with `compatible = "ramoops"`, reg + record-size properties — provenance-commented per §13 DT rule) + cmdline belt-and-braces (`ramoops.mem_address=… ramoops.mem_size=… ramoops.record_size=…` matching DT — mismatch boots but logs `ramoops: disagrees with DT` and the boot-lint job fails the build so the disagreement can't ride).

Verification ritual (per release, per variant, sacrificial only): eng build, `echo c > /proc/sysrq-trigger` (documented window — lab bench, charger attached, serial logging), warm-reset, then `cat /sys/fs/pstore/console-ramoops-0` + `dmesg-ramoops-0` + `pmsg-ramoops-0` all non-empty with the sysrq signature line present; `halide-early.service` collection (§2 ch.05) verified (files land in `/var/lib/halide/pstore/<boot-id>/` with correct boot-id linkage — orphan pstore files with no boot-id fail the check). Negative tests: ramoops region survives 50-cycle suspend (§17 script tail checks `pstore` mount health), survives OTA slot switch (A→B preserves last-crash across slots — crash-then-update sequence tested pre-release), never contains keying material (redaction scan: grep for `BEGIN PRIVATE` + keymaster patterns — ramoops captures kernel memory-adjacent text, the scan proves no key spilled; failure = Security P0).

## 31. Scheduler/cpufreq tuning log (performance per watt, written down)

Policy baseline per SoC (`power/<sku>/sched-cpufreq.md`): scheduler (`EAS`/`schedutil` vs `performance` per-cluster rationale — phone defaults stage from energy-model presence: no energy-model = no EAS claims, measured comparison committed instead), governor parameters (`schedutil` rate-limit + iowait-boost values with before/after jank medians §14 ch.06 — boost values copied from stock without measurement flagged like datasheet curves), `cpufreq`/`devfreq` boost wiring from `IPower` hints (ch.04 §21 runbook values mirrored here with host-side effect: hint → freq transition latency measured in ms, storm-test counter referenced). Uclamp discipline: per-task `uclamp.min` only for audio present thread + composer present thread (ch.06 §12 prio map cites these; any new uclamp.min needs the power-vs-jank tradeoff measurement attached or review-bounced — uclamp creep quietly doubles idle current).

Tuning log format (append-only, newest-first like boot OPT-LOG §28): change + workload (`workload-jank.sh` + sustained-perf soak ch.04 §25) + jank delta + power delta (both numbers, same ambient footnote honesty ch.10 §8 — single-sided wins rejected: a 10% jank win at 30% more idle current ships only with Arch + QA joint sign naming the tradeoff in release notes). Forbidden defaults (review-lint): `performance` governor on release builds (eng-only with banner), disabled `schedstats`-shaped debug overhead left on (debug configs measured-off before merge — leftover tracing that costs 2% battery is a bug with a commit hash).

## 32. Toolchain bump procedure (clang moves — deliberately, with proof)

Pinned toolchain (§2/§11) bumped only on GKI guidance or CVE: bump PR records old→new `clang --version` + LTO behavior note + full CI (§25) + 5-boot medians (§28 timeline — codegen shifts move boot time ±3% silently; the medians prove direction) + `diffoscope` on `Image.gz` pair (expected: widespread benign deltas; unexpected: identical bytes claim investigated — same-bytes across a clang major bump means the toolchain didn't actually switch). Rollback: previous container digest retained one release (revert = one-line digest + MANIFEST note, validated by the same medians).

## 33. Scheduler / cpufreq / cpuidle governor policy per cluster (power numbers attached)

REF-A shape (SDM845: 4× Kryo 385 Gold + 4× Kryo 385 Silver) is the template; REF-B repeats this section with its own numbers (never copy frequencies across SoCs — DVFS tables are silicon-specific). Policy: `schedutil` on all clusters (single governor v1 — no per-cluster governor mixing; mixing breaks EAS cost-model assumptions and makes boost-hint triage ambiguous). `intel_pstate`-style reasoning does not apply; this is `cpufreq-dt`/qcom-cpufreq-nvmem driven with OPP tables from DT.

Per-cluster policy file (`power/<sku>/cpufreq-policy.conf`, applied by `halide-cpufreq.service` after `halide-cpufreq.service` validates OPP signatures against DT):

```
# gold0-3 (big): latency-sensitive (composer present, audio DSP kick, RIL BH)
GOLD: governor=schedutil rate_limit_us=500 iowait_boost=1 hispeed_freq=1766400 hispeed_load=85 min=825600 max=2803200 uclamp_min_present_tasks_only=1
# silver0-3 (little): background (logd, sync, netd-bridge polling, sensors batch drain)
SILVER: governor=schedutil rate_limit_us=1000 iowait_boost=0 hispeed_freq=1209600 hispeed_load=90 min=576000 max=1766400
```

Rationale per knob (measured, not defaulted): `rate_limit_us` 500/1000 (gold faster ramp for touch→photon budget ch.06 §7 <100ms; 200-tap runs at 500 vs 2000 showed +6ms p95 win gold, +0.4mA idle cost — accepted with measurement in `power/<sku>/sched-cpufreq.md` §31 companion); `iowait_boost` gold-only (storage stalls on gold: app launch; silver iowait-boost caused 11% idle-current lift in 8h suspend-with-sync test — disabled with the number attached); `hispeed_freq/load` set at the knee of the OPP efficiency curve (see table below — frequencies above the knee cost >2× power per +10% DMIPS and are boost-only, never sustained).

OPP efficiency table (SDM845 REF-A, binned per unit at 25°C, external meter, calibration footnote per ch.10 §8; REF-B own table):

| Cluster | OPP (kHz) | V (mV) | Dhrystone rel | Δ current vs idle (mA) | Role |
|---|---|---|---|---|---|
| Silver | 576000 | 640 | 0.31 | +18 | suspend-drain, sensor batch |
| Silver | 1209600 | 760 | 0.62 | +55 | hispeed default |
| Silver | 1766400 | 880 | 0.88 | +140 | burst only (boost hint ≤2s) |
| Gold | 825600 | 680 | 0.45 | +45 | floor (never lower — L2 flush cost exceeds saving) |
| Gold | 1766400 | 800 | 0.78 | +160 | hispeed/interaction |
| Gold | 2361600 | 920 | 0.95 | +380 | sustained-perf ceiling (thermal §25 ch.04 throttles from here) |
| Gold | 2803200 | 1000 | 1.00 | +620 | transient only (≤500ms, storm-guarded) |

Rules with teeth: max-frequency sustained >2s requires `SUSTAINED_PERFORMANCE` hint path (ch.04 §21/§25 — raw `userspace` governor writes to `scaling_max_freq` from container denied by sepolicy + host polkit; only `halide-power` daemon may raise ceiling, rate-limited, logged). `performance` governor forbidden on release (CI `boot-lint`-style grep on `cpufreq-policy.conf` for release branch — `performance` string fails build with pointer here). Powersave floor: silver min 576000 (lower OPPs exist in silicon but entry/exit latency 1.8ms breaks sensor-batch drain deadlines — measured, committed).

EAS/energy-model: `sched_energy_aware=1` only where DT provides `energy-cost` + `capacity-dmips-mhz` (verify `dmesg | grep -i energy` + `/proc/schedstat` EAS counters increment under load-mix test: 2 big + 4 little busy-loop 60s must place background threads little ≥90%). No energy model → EAS off + documented (no EAS claims without model — §31 rule restated at the knob level). `schedtune`/`uclamp` (see §31): only audio-present + composer-present carry `uclamp.min` (values in `graphics/prio-map.txt` + `audio/<sku>/policy.json` — triple-cited so drift in one file fails review of the others). New `uclamp.min` requests attach the power-vs-jank pair or are bounced.

Cpuidle: `menu` governor, all C-states enabled except `pc_bias`-style deep modem-coupled states during voice call (call profile in `power/<sku>/call-cpuidle.conf`: deepest silver C-state blocked during `media.role=Phone` active — modem DRX + cpuidle race causes 40ms audio gaps, root-caused once, written down). Verify `cpupower idle-info` + 8h idle residency (`/sys/devices/system/cpu/cpuidle/*/time` deltas — deepest state ≥85% residency in airplane-idle or the wakeup audit §8 names the stormer).

Boost-hint wiring (host side of ch.04 §21): `INTERACTION` → gold hispeed clamp 500ms; `SUSTAINED` → ceiling table above + thermal severity gate (SEVERE denies boost, logged — boost-during-throttle is how phones melt benchmarks and burn users); storm test 200 hints/10s → rate-limiter holds (counter in metrics, §21 drill references this policy file hash so drill and policy can't drift).

## 34. Memory management tuning (zram / zswap / LMK / lmkd / PSI thresholds)

Single truth: host owns memory pressure policy; Android `lmkd` runs inside container but kills only container processes (host `systemd-oomd` never kills container init — container is one cgroup subtree with its own pressure handling; cross-kill is a P0 bug). Swap posture v1: zram only, no disk swap (eMMC/UFS swap wears flash + LUKS2 dm-crypt swap doubles write-amp — rejected with the wear math in `power/<sku>/memory.md`), no zswap (zswap + zram double-compression wastes CPU for <3% ratio win measured on REF-A — number committed, re-argued only with new data).

zram config (`/etc/systemd/zram-generator.conf` on host + container-local zram for dalvik heap pressure):

```
[zram0]
zram-size = min(ram * 0.5, 2048)   # 4GB SKU→2048MB, 6GB→2048MB cap (cap rationale: >2GB zram on 4GB device starves page-cache, measured thrash at 2.5GB)
compression-algorithm = lzo-rle     # not zstd: zstd +12% ratio but 2.1× CPU on little cluster during batch-kill storms (measured, `zramctl --stats` + `perf` in memory.md)
swap-priority = 100
```

Container dalvik heap sizing (`device/halide/<sku>/device.mk`: `dalvik.vm.heapgrowthlimit=256m` 4GB / `384m` 6GB+, `heapmaxfree=8m`) matched to zram (heap too large + small zram = direct-reclaim stalls visible as scroll jank — frame-join fence-wait vs reclaim-wait disambiguation in ch.06 §14 triage ladder gains a `reclaim-wait` classifier fed by `psi` below).

lmkd params (container `lmkd` + host `systemd-oomd` split): container `lmkd` (`/vendor/etc/lmkd.conf`): `minfree_levels=18432,23040,27648,32256,55296,80640` (pages, tuned per RAM variant — DRAM-size fork §19 ch.02 companion: 4GB vs 6GB tables side-by-side in repo, never one table with "adjust for RAM" prose), `kill_heaviest_task=true`, `kill_timeout_ms=100`, PSI-mode enabled (`ro.lmk.psi_complete_stall_ms=150`, `ro.lmk.psi_partial_stall_ms=200`, `ro.lmk.thrashing_limit=100`). Host `systemd-oomd` (`/etc/systemd/oomd.conf`): `DefaultMemoryPressureDurationSec=30s`, container subtree `ManagedOOMMemoryPressureLimit=80%` action `none` (monitor-only — host never SIGKILLs container; pressure signal forwarded to container lmkd via `/run/halide/memory-pressure` event + banner, so the kill decision stays in the stack that understands adj scores).

PSI thresholds (both stacks read the same kernel source — single instrumentation, two consumers): host monitors `/proc/pressure/{cpu,memory,io}` 10s windows via `halide-psi-monitor.service`; alert lines: `memory some avg10 >20%` sustained 30s → journal `MEMORY-PRESSURE` + metric (feeds jank dashboard — scroll-jank during PSI>20% classified expected-physics per ch.06 §14 thermal-arbitration pattern extended to memory); `memory full avg10 >5%` → container lmkd aggressive pass + host defers non-critical batch (sync, dexopt, logrotate — `ConditionMemoryPressure=` stanzas on those units); `io full avg10 >10%` during app launch → UFS-clkscale audit (ch.03 §15 `clkscale`/`hibern8` state dumped — io-stall with clocks gated is policy, without is driver). Test: `stress-ng --vm 4 --vm-bytes 80%` 5-min soak per RAM variant (PSI traces archived; lmkd kill log shows cached→empty→perceptible order, never foreground kill — foreground kill = P0, reproducer attached).

Swappiness/drop-caches discipline: `vm.swappiness=100` inside container (Android convention — anonymous→zram aggressively), `vm.swappiness=60` on host (page-cache protective — host file servers matter more than anonymous), `vm.watermark_boost_factor=15000`, `vm.watermark_scale_factor=125` (reclaim-ahead for camera-preview concurrency — preview + display + iperf triple test ch.03 §13 re-run after any watermark change with frame-drop delta attached). `drop_caches` in scripts banned except the triage runbook's cold-cache boot test (§28 — any other `echo 3 > drop_caches` fails review with link here).

 Low-memory killer verification (per release, per RAM variant): `lmkd-test` (fill to each minfree level, assert kill order + `sys.boot_completed` stays 1 + foreground app survives to `PERCEPTIBLE` boundary), 50-app open/close churn (no `sys.boot_completed` flap, no host OOM journal), camera 12MP burst during PSI>15% (no green frames — reclaim stall vs ISP stride §9 ch.04 disambiguation logged). Results table in `power/<sku>/memory.md` next to OPP table §33 (memory and scheduler share the page — pressure moves frequency, frequency moves reclaim, one page prevents split-brain tuning).

## 35. USB / PCIe bring-up detail (roles, PHY, power, fault ladders)

USB controller (`dwc3-qcom` dual-role, ch.03 §15 expanded to bring-up depth): DT nodes (`dwc3` + `qcom,usb-ssphy` + `extcon` + `role-switch` + `vbus-regulator` with provenance comments per §13), PHY tuning (SSPHY `tx-deemphasis` + `tx-swing` per SKU from SI report or stock dump — values committed in `devices/<sku>/usb-phy.conf` with source tag `SI-MEASURED`/`STOCK-DUMP`/`DEFAULT-UNTESTED`; `DEFAULT-UNTESTED` blocks Phase-2 gate — untested PHY values ship bit errors at temperature), `maximum-speed` (`super-speed` REF-A verified with `lsusb -t` 5000M; `high-speed` fallback recorded where signal integrity marginal with the eye-diagram ticket linked).

Role matrix (tested states — every cell run per release, result in `hw/<sku>/usb-matrix.csv`):

| Host role | Gadget funcs (ch.04 gadget matrix companion) | Cable | Orientation | Expect |
|---|---|---|---|---|
| device | adb | C-to-C | flip ×2 | `adb devices` + no re-enumerate storm (`dmesg` re-enumerate count ≤2) |
| device | adb+mtp | C-to-C | flip ×2 | both interfaces enumerate, MTP browse 100 files |
| device | ptp | C-to-A | — | `gphoto2 --auto-detect` lists |
| device | rndis | C-to-C | — | host-IP on PC side, leak test ch.05 §VPN unaffected (rndis is tether-surface, firewall default-deny logged) |
| host | — (ADB to accessory) | C-to-A + OTG adapter | — | accessory enumerates, `lsusb` VID/PID logged, VBUS current ≤500mA w/o PD |
| host | +DP-alt-mode query | C-to-C DP-capable | flip ×2 | `drm_info` DP connector appear/disappear 50× no wedge (ch.06 §15 precondition cell) |

Autosuspend/power: `usbcore.autosuspend=-1` for modem-QMI interfaces (autosuspend on QMI = 3s data stalls root-caused once — quirk committed with the trace), `auto` (2s) for MTP/PTP gadget + accessory ports; `power/control` states dumped in suspend audit (§8/§17 — USB wakeup enabled only for defined gesture wake §8, charger wake §13 ch.03; every other `enabled` is a finding). Charger detection (`qcom,qpnp-smb`): SDP/CDP/DCP/HVDCP distinguish logged (`/sys/class/power_supply/usb/type` + current-max negotiated — wrong type = slow-charge complaints with no logs; the type line is mandatory in battery reports ch.04 health §21 agreement table context).

PCIe (`pcie-qcom`, Wi-Fi ath10k/cnss + NVMe where present): link training log (`dmesg | grep -i pcie` L0s/L1 + width×speed negotiated vs DT `max-link-speed` — downgraded link (×1 Gen1 where ×1 Gen2 expected) investigated as SI/power, not accepted silently), ASPM policy (`pcie_aspm=force` + `L1SS` where endpoint advertises; measured idle delta in `power/<sku>/pcie.md` — ASPM-off powers through suspend and the wakeup audit names it), reset GPIO + `vdda` regulator sequencing (per-endpoint `reset-assert-ms`/`deassert` from datasheet with scope-capture on first bring-up — PCIe devices that need 100ms reset held in reset 10ms enumerate intermittently and waste months), MSI vs legacy IRQ (`/proc/interrupts` shows MSI per endpoint — legacy IRQ sharing with touch IRQ is a latency bug for ch.06 §7 touch p95, checked once per SKU).

Fault ladders: no-enumerate → PHY clock (`clk_summary` SSREF on?) → VBUS (`regulator_summary` + meter) → role (`extcon` state vs cable — flipped cable same failure = role-switch driver, one-orientation = CC pin/SBU hardware) → DT `dr_mode`/`usb-role-switch` property typo (most common, `dtbs_check` + `fdtdump` diff first). PCIe no-link → PERST timing → REFCLK (`clk_summary`) → regulator → LTSSM state dump (`/sys/kernel/debug/pcie*/` where exposed) → reseat/reflow note (mechanical logged with traveler ID ch.04 §17 — lab-connector wear tracked, not hidden). USB-C orientation bugs get their own BUG tag `USB-ORIENTATION` (pattern from §15 restated with triage ownership — orientation-only failures route to hardware/SI, both-orientation to driver).

## 36. RTC / alarm-timer architecture for both stacks (one clock, two alarm managers)

Hardware truth: PMIC RTC (`rtc-pm8xxx`) is the single timekeeper across suspend (no second RTC — modem `time` services are clients, not sources). Kernel: `CONFIG_RTC_DRV_PM8XXX=y` + `CONFIG_RTC_HCTOSYS=y` (`hctosys` restores wall time at boot before systemd — boot-timeline §28 `dmesg` vs journal clock-jump audit must show ≤1s discontinuity or the timeline tool flags `CLOCK-JUMP`), `CONFIG_ALARM`/`CONFIG_RTC_ALARM` + `timerfd`/`alarmtimer` for Android (`AlarmManager` needs `ANDROID_ALARM` clock IDs — verify `/dev/alarm` or `alarmtimer` compat per GKI version with the exact node name per LTS recorded; GKI LTS bumps rename this path and the §26 stable-triage must flag `drivers/rtc` + `kernel/time/alarmtimer.c` commits for HW attention).

Stack split (mirrors modem/netd single-owner doctrine — time has one owner per direction): host `systemd-timesyncd` owns wall-clock discipline (NTP, `RootDistanceMaxSec=5`, `PollIntervalMinSec=32`); Android `AlarmManager`/`CalendarTrigger` own app wakeup scheduling inside container (alarms delivered via container-local `alarmtimer`, never by programming PMIC RTC directly from container — container RTC writes denied by device ACL + sepolicy neverallow §14 ch.04). Wakeup-alarm bridge (`halide-alarm-bridge.service`): container `AlarmManager` next-wakeup (`dumpsys alarm` `nextWakeup`) mirrored to host `rtcWakeAlarm` (`/sys/class/rtc/rtc0/wakealarm`) through the bridge with `SO_PEERCRED` auth (only `system_server` UID may post — same pattern as audio-proxy ch.04 §8); host programs the single hardware wakeup = min(host wakeup, container next-wakeup, modem DRX page — three-source min computed in bridge, each source logged at debug so missed-wake triage starts from the min computation, not from vibes).

Suspend/wake integration: `mem_sleep=[deep]` (§8) + `rtcWakeAlarm` programmed before every suspend (`halide-suspend-prepare` hook asserts wakealarm armed when container reports pending wakeup — unarmed-suspend-with-pending-alarm fails closed with journal `ALARM-NOT-ARMED` + aborts suspend once (retry armed) so alarms never silently slip); `rtcwake -m mem -s 10` (§17 script) extended with alarm cross-check (program container-side `cmd alarm` test alarm +5s before each cycle — wakeup source must read `rtc0`, not touch/USB; wrong-source wakes counted separately in `logs/suspend.txt`). Timezone: host owns tzdata (`/etc/localtime`); container tz slaved via bridge (`persist.sys.timezone` mirrored on host change + host change mirrored from container Settings where user edits Android clock — single truth enforced by last-writer-wins with 2s debounce + conflict journal; dual-tz divergence (host UTC+1, container UTC+2) fails `halide-android-health` §15 ch.04 contract with named error).

GNSS/time-integrity adjacency (ch.04 time-integrity consumer): modem NMEA/QMI time + NTP + RTC vote in `halide-time-vote` (logic: RTC trusted across reboot, NTP trusted when `RootDistance<5s`, GNSS trusted only with ≥4 SV + fix-valid flag — week-rollover-corrupted GNSS time (ch.04 §33 predecessor note) can never outvote NTP+RTC; 2-of-3 agreement required to step clock >10s, else slew + `TIME-UNTRUSTED` metric + banner where user-visible). `timedatectl` + `adb shell dumpsys alarm` agreement asserted in contract tests (ch.04 §22 layer-2 gains `halide-time-check`: host epoch vs container epoch Δ≤2s + next-wakeup armed agreement). DST/all-day alarm soak: 20 programmed alarms across a DST boundary + 50-cycle suspend (§17) with alarm armed — 0 missed, 0 early-by-hour (classic tz-bridge bug shape, tested explicitly not hopefully).

## 37. Kernel cmdline registry (every param documented with owner — no mystery flags)

Rule: every `cmdline` token in `mkbootimg` (§6) + DT `bootargs` + bootloader-appended `androidboot.*` appears in this registry table (`boot/<sku>/cmdline-registry.md` is normative — CI `boot-lint` greps built `boot.img` cmdline against the registry; unregistered token fails build with pointer here; registry drift is how `nowatchdog`-in-release (§19) and `nokmem`-forever (§12) happen). Columns: param | value(s) | owner | why | forbidden values | test.

| Param | Value | Owner | Why | Forbidden | Test |
|---|---|---|---|---|---|
| `console` | `ttyMSM0,115200n8` | Kernel | early bring-up + pstore-adjacent triage (§9) | `tty0`-only (loses pre-fb logs) | UART prompt on eng |
| `androidboot.hardware` | `qcom`/`halide-<sku>` | Android/BSP | HAL variant select (`ro.hardware`) | generic `default` (loads wrong audio/camera policy) | `getprop ro.hardware` matches SKU |
| `androidboot.memcg` | `1` | Kernel | AOSP lmkd cgroup accounting (§12 note) | `0` (lmkd blind) | `lmkd` PSI mode active |
| `cgroup.memory` | `nokmem` | Kernel | legacy AOSP lmkd quirk (§12 — TEMPORARY, removal release named) | permanent w/o review date | ledger §20 entry cites this row |
| `printk.devkmsg` | `on` | Kernel | container `dmesg` visibility for triage | `off` on eng (blinds lab) | `logcat -b kernel` non-empty |
| `printk.time` | `1` | Kernel | boot-timeline joins (§28 — always-on) | `0` (unjoinable logs) | timeline tool parses |
| `initcall_debug` | present eng / absent release | Kernel | initcall ranking §29 | present release (overhead + log spam) | release cmdline grep-absent in CI |
| `systemd.unified_cgroup_hierarchy` | `1` | Platform | cgroup-v2 single tree (§12) | `0` (v1 split breaks lmkd PSI) | `mount \| grep cgroup2` |
| `ramoops.mem_address/size/record_size` | per-variant §30 | Kernel | must match DT (§30 mismatch fails build) | copied across RAM variants | §30 sysrq ritual per variant |
| `kgdboc/kgdbwait` | eng-only | Kernel | early-debug §17 | any release presence (CI neverallow-eng analog) | release grep-absent |
| `nowatchdog` | eng-kgdb-only | Kernel | §19 (release forbids) | release (CI grep) | watchdog pet log on release |
| `pcie_aspm` | `force` | Kernel/BSP | §35 ASPM policy | `off` w/o §35 power note | `pcie.md` idle delta filed |
| `usbcore.autosuspend` | `-1` (QMI quirk §35 documents the exception, not the global) | Kernel | §35 per-interface policy is normative; global stays default `2` | global `-1` (kills suspend power) | suspend audit USB rows |
| `sched_energy_aware` | `1` iff energy-model present §33 | Kernel | EAS honesty rule | `1` w/o model (fake EAS) | EAS counters under mix test |
| `dm-mod.create`/`verity` | per-slot AVB §6 | Security | verified-boot chain | `verify=off` outside eng-orange | AVB green check ch.09 |
| `luks.*`/`rd.luks` | per LUKS2 ch.09 | Security | userdata encryption | `rd.luks=0` anywhere | encryption-state test |
| `androidboot.slot_suffix` | `_a`/`_b` (bootloader-set) | Bootloader | A/B (§6/§18 ch.03) | hardcoded (breaks OTA slot) | slot-switch test preserves ramoops §30 |
| `audit`/`selinux` | `audit=1 enforcing=1` release | Security | MAC enforcing gate (§12) | `enforcing=0` outside eng | `getenforce` both namespaces |
| `quiet`/`loglevel` | `loglevel=4` release / `7` eng | Kernel | release log-spam vs triage balance | `quiet` hiding ramoops-relevant oops | forced-warning appears in pstore |

Bootloader-appended params (`androidboot.serialno`, `androidboot.bootreason`, `androidboot.verifiedbootstate` green/orange/red, `androidboot.vbmeta.*` digests) are READ-ONLY inputs (kernel/registry records expected value sets per boot state — `verifiedbootstate=red` must halt userspace pivot with pstore event, tested by rollback-rejection case §6). `bootreason` vocabulary pinned (`reboot,cold,watchdog,resin,alarm,crash` — unknown reasons logged `BOOTREASON-UNKNOWN` + BUG, never silently mapped to `cold`). Registry review: every LTS bump (§26) + every bootloader change (§18) re-validates the table (param renamed upstream → triage file names it; stale registry entries past one release get `STALE-` prefix + removal BUG — registry rot is how mystery flags return).

## 38. CPU idle-state (cpuidle) table per cluster + residency targets + measurement via sysfs + verification

REF-A template (SDM845: 4× Kryo 385 Gold + 4× Kryo 385 Silver); REF-B repeats with its own silicon numbers — never copy residency/latency across SoCs. Governor: `menu` (§33); `ladder` forbidden on arm64 (selection hysteresis wrong for clustered power domains — `menu` + `teo` comparison committed in `power/<sku>/cpuidle-governor.md`, `teo` kept as eng experiment only until 8h idle A/B proves parity). DT source: `cpu-idle-states` + `domain-idle-states` nodes with provenance comments per §13 (stock dump vs measured vs datasheet §9.4-style cite); any state without `exit-latency-us` + `min-residency-us` + `local-timer-stop` flag is review-fail.

| State | Cluster | HW meaning | Exit-lat (us) | Min-residency (us) | `local-timer-stop` | Role |
|---|---|---|---|---|---|---|
| WFI | Silver/Gold per-CPU | clock-gated, L1 retained | 2 / 2 | 5 / 5 | 0 | syscall-idle, irq-heavy phases (touch poll) |
| C1 (cpu-sleep-0) | Silver | L1 off, L2 retained, timer running | 45 | 200 | 0 | short gaps (composer vsync wait, 16ms cadence) |
| C1 (cpu-sleep-0) | Gold | L1 off, L2 retained, timer running | 60 | 250 | 0 | same, gold ramp headroom for interaction |
| C2 (cluster-sleep-0) | Silver cluster | L2 off, CCI still on, timer stopped | 450 | 1200 | 1 | suspend-drain, sensor batch gaps |
| C2 (cluster-sleep-0) | Gold cluster | L2 off, CCI still on, timer stopped | 650 | 1800 | 1 | deep idle between interaction bursts |
| C3 (apss-sleep / XO shutdown) | both (system) | APSS + XO off, RPMH holds votes, modem DRX independent | 2500 | 8000 | 1 | airplane-idle / screen-off music / `mem` suspend path entry |

Residency targets (external-meter truth + sysfs time counters, same ambient footnote honesty ch.10 §8; numbers are 8h airplane-idle medians on sacrificial REF-A, charger detached, SIM present, Wi-Fi off):

| Scenario | Silver deepest (C2+C3 share) | Gold deepest | WFI share ceiling | Meter idle (mA) |
|---|---|---|---|---|
| airplane-idle screen-off 8h | ≥85% | ≥80% | ≤5% | ≤8 (REF-A 4GB) |
| screen-off + sensor batch 50Hz 8h | ≥70% | ≥65% | ≤10% | ≤14 |
| screen-off music (DSP offload) 4h | ≥60% | ≥55% (gold mostly power-collapsed) | ≤12% | ≤28 |
| voice call (modem DRX, §33 call profile) | ≥40% silver (deepest-blocked variant) | ≥30% | ≤20% | ≤95 |

Measurement runbook (host shell, no container dependency — idle measured at host so Android wakelocks can't hide inside container stats):

```bash
# 1. topology + governor + enabled states
cat /sys/devices/system/cpu/cpuidle/current_governor_ro  # expect menu
cpupower idle-info  # per-CPU state table + disabled flags
for c in 0 4; do echo "== cpu$c =="; \
  cat /sys/devices/system/cpu/cpu$c/cpuidle/state*/name; \
  cat /sys/devices/system/cpu/cpu$c/cpuidle/state*/desc; done
# 2. latency/residency as kernel sees them (must match DT table above)
for c in 0 4; do for s in /sys/devices/system/cpu/cpu$c/cpuidle/state*; do \
  echo "$s $(cat $s/name) lat=$(cat $s/latency) res=$(cat $s/residency) dis=$(cat $s/disable)"; done; done
# 3. snapshot counters, soak, delta (8h airplane-idle or 1h short-gate)
for f in /sys/devices/system/cpu/cpu*/cpuidle/state*/time; do echo "$f $(cat $f)"; done > /tmp/cpuidle-before.txt
for f in /sys/devices/system/cpu/cpu*/cpuidle/state*/usage; do echo "$f $(cat $f)"; done >> /tmp/cpuidle-before.txt
sleep 3600  # short-gate; release gate uses 28800
for f in /sys/devices/system/cpu/cpu*/cpuidle/state*/time; do echo "$f $(cat $f)"; done > /tmp/cpuidle-after.txt
python3 scripts/cpuidle-residency.py --before /tmp/cpuidle-before.txt --after /tmp/cpuidle-after.txt --format md | tee logs/cpuidle-residency.txt
# Expected: residency % table matching targets above; script exits nonzero on target miss with named state
# 4. cross-check against wakeup audit (§8/§17) + power meter in same run
cat /sys/kernel/debug/wakeup_sources | sort -k7 -n -r | head -10 | tee -a logs/cpuidle-residency.txt
cat /sys/kernel/debug/clk/clk_summary | grep -i -e xo -e gcc | tee -a logs/cpuidle-residency.txt
```

Expected outputs: `current_governor_ro` → `menu`; `cpupower idle-info` shows 3 states per CPU, none `disabled` except call-profile override (§33 `call-cpuidle.conf` asserts via `halide-cpuidle-apply` log line `CALL-PROFILE active: silver-C2 blocked`); `residency.py` prints per-cluster `%WFI / %C1 / %C2 / %C3` + `PASS/FAIL` per scenario row; wakeup top-5 unchanged vs baseline (±10% — new stormer + residency miss = single BUG with both logs attached, not two bugs).

| Knob/audit | Owner | Why | Test |
|---|---|---|---|
| `menu` governor + DT `cpu-idle-states` | Kernel/BSP | wrong governor hides 2× idle-current regression | `current_governor_ro` + 8h meter |
| `local-timer-stop` flags | Kernel/BSP | mistagged timer-stop breaks `broadcast-timer` + causes early wakes | `dmesg \| grep -i broadcast` clean + residency |
| call-profile C-state block (§33) | Power/Audio | modem-DRX + deep-cpuidle race = 40ms audio gaps | call soak + gap counter 0 |
| `cpuidle-residency.py` CI gate | Power/QA | residency is the only idle metric that survives meter-calibration disputes | nightly HW job green |
| broadcast-timer + `arch_timer` errata | Kernel/BSP | SDM845 timer broadcast misroute adds 300 wakes/h (measured once) | `timer_migration` + wakes/h |

Troubleshooting ladder (residency miss → cause in order, no skipping): (1) `disable` flags (`cat state*/disable` — call-profile left armed after call? `halide-cpuidle-apply` idempotency bug, fix + regression test); (2) wakeup storm (`wakeup_sources` delta vs baseline §8 — stormer >100/s explains any miss, fix storm first); (3) timer tick (`cat /proc/timer_list` + `powertop --html` wakeups — `NO_HZ_FULL` misconfig or `local-timer-stop=0` state absorbing residency); (4) clk vote held (`clk_summary` XO never off — RPMH vote leak, `pm_genpd_summary` + `interconnect_summary` dump); (5) governor selection (`ftrace cpuidle` 60s: `echo 1 > events/power/cpu_idle/enable` — `menu` predicted-shallow pattern = `correction_factor` or noisy `next_timer_us`); (6) thermal/freq clamp (§33 `scaling_max_freq` pinned by thermal — hot idle never enters C3, ambient note decides silicon-vs-lab). Each step logs to `logs/cpuidle-triage-<date>.txt`; residency FAIL without attached triage log is not actionable and QA returns it.

## 39. IOMMU/SMMU mapping audit (fwspec, stream IDs, fault log triage)

Threat model: display (MDSS), camera (CAMSS/IFEs), modem (via `rmnet` DMA), USB, PCIe/Wi-Fi, and audio DSP all DMA through `arm-smmu` (§12 `ARM_SMMU=y` is load-bearing — `iommu.passthrough=1` anywhere outside eng-debug fails release `boot-lint` with pointer here). Every DMA master has a DT `iommus = <&apps_smmu SID mask>` fwspec with provenance comment (§13); every SMMU context bank (CB) has an owner, a domain type (`DMA` vs `IDENTITY` — IDENTITY allowed only for the display linear framebuffer carveout with Security sign, expiry release named), and a fault-log triage entry. Unmapped-master DMA that happens to work (1:1 PA == IOVA luck) is a P0 — works-on-bench, faults-in-field under CMA pressure.

```bash
# 1. SMMU presence + driver + fault counters (host, post-boot)
dmesg | grep -i -e smmu -e iommu | tee logs/smmu-probe.txt
# Expected: arm-smmu probed, CBs allocated, NO "Unexpected global fault" / "Unhandled context fault" lines
ls /sys/kernel/iommu_groups/ | sort -n | tee -a logs/smmu-probe.txt  # one group per master+CB binding
for g in /sys/kernel/iommu_groups/*/devices/*; do echo "$g -> $(readlink $g)"; done | tee -a logs/smmu-probe.txt
# 2. fwspec audit: DT-declared SIDs vs live bindings (CI + per-release)
scripts/smmu-audit.py --dtb out/<sku>/arch/arm64/boot/dts/qcom/*.dtb --sysfs /sys/kernel/iommu_groups --out logs/smmu-audit.txt
# Expected: every DT iommus phandle resolves to a live group; no live group without DT provenance; script exits nonzero listing orphans
# 3. live fault + TLB + mapping health under concurrency stress (camera preview + display + iperf triple, §13 icc companion)
cat /sys/kernel/debug/iommu/io-pgtable-stats 2>/dev/null | tee logs/smmu-stress.txt
echo 1 > /sys/kernel/debug/tracing/events/iommu/enable 2>/dev/null || echo "iommu tracepoints N/A on this LTS (note LTS in log)"
halide-camera-preview --60s & halide-display-stress --60s & iperf3 -c <srv> -t 50; wait
dmesg | grep -i -e "context fault" -e "global fault" -e "translation fault" -e "permission fault" | tee -a logs/smmu-stress.txt
# Expected: zero fault lines; any line = FAIL with FAR/FSR capture below
# 4. per-master stream-ID table dump (archived per release — SID drift means firmware/DT changed)
cat /sys/kernel/debug/arm-smmu/*/devices 2>/dev/null | tee logs/smmu-sids.txt
fdtdump out/<sku>/dtb | grep -B3 -A3 iommus | tee -a logs/smmu-sids.txt
```

Expected outputs: `smmu-probe.txt` shows `arm-smmu-v2/v3` probe + `pagetable: 48-bit` + groups for `mdss`, `camss`, `usb_dwc3`, `pcie`, `lpass` (exact masters per `hw/<sku>/smmu-masters.csv`, committed); `smmu-audit.py` → `AUDIT PASS: N masters, 0 orphans, 0 missing`; stress run → `0 context faults / 0 global faults` with `io-pgtable-stats` alloc/free balanced (leak = unmap-missing driver bug, P1).

| Master | Stream IDs (REF-A example, per-SKU CSV normative) | CB / domain | Owner | Why | Test |
|---|---|---|---|---|---|
| MDSS (display) | 0x1800–0x18FF | DMA + IDENTITY carveout (linear FB, Security-signed) | Display/Kernel | underrun-path faults blank screen, not logspam | triple-stress 0 faults + `modetest` survives |
| CAMSS IFE0/1/2 | 0x2000–0x23FF | DMA, 4K+64K pages, prefetch on | Camera/Kernel | stride-mismatch faults green-frame (ch.04 §9 adjacency) | 12MP burst + preview 0 faults |
| Adreno GPU (GMU) | 0x1000–0x17FF | DMA, per-context TTBR (per-process pagetables) | Graphics/Kernel | GPU fault wedges composer (ch.06 §14 `fence-wait` vs `fault-wait`) | `deqp` + composer 0 faults |
| USB DWC3 | 0x2C00–0x2C1F | DMA, coherent | BSP/Kernel | MTP bulk faults corrupt transfers silently | 10GB MTP round-trip sha256 + 0 faults |
| PCIe (Wi-Fi) | 0x3000–0x301F | DMA, MSI-mapped | Net/Kernel |aquin fault drops rx rings under iperf | iperf 60s + 0 faults |
| LPASS (audio DSP) | 0x2800–0x28FF | DMA, small-page only (4K — DSP TLB erratum, datasheet cite) | Audio/Kernel | wrong pagesize = underrun gaps, not faults (silent) | offload playback + gap counter |

Fault-log triage runbook (every SMMU fault line gets this parse — unparsed fault logs are not triage): ARM SMMU fault line shape `arm-smmu <addr>: Unhandled context fault: fsr=0x<X>, iova=0x<Y>, fsynr=0x<Z>, cb=<N>` → (1) `cb` → master via `smmu-masters.csv` (unknown CB = DT/CB alloc drift, §26 stable-triage must flag `drivers/iommu/arm-smmu*` commits); (2) `iova` → map owner (`/sys/kernel/debug/iommu/maps` + driver `dma_map` trace — IOVA near 0 = unmapped-buffer DMA (use-after-unmap/driver-missing-`dma_map`), IOVA mid-range with `permission fault` = cache-maintenance or prot-bit bug); (3) `fsr/fsynr` class (`Translation` vs `Permission` vs `Access` — Translation under concurrency = IOVA exhaustion/CMA pressure (check `cma_alloc` failures + `buddyinfo`), Permission = driver passing wrong `dma_data_direction`); (4) capture `devmem`-free dump (`devcoredump` where driver supports + `iommu_dump` debugfs + `dmesg` 200-line window + triple-stress repro flag) into BUG with `SMMU-FAULT` tag; (5) Security adjudicates IDENTITY-carveout-adjacent faults same-day (carveout overrun = memory-safety boundary, not display bug). Global faults (`GFSR`) route to SMMU-driver owner directly (config/clock, not master driver — misrouted global-fault BUGs get bounced with link here).

## 40. Devicetree overlay build + sign + apply flow (dtbo img, vbmeta descriptors, rollback on bad overlay)

One DTB per board + one DTBO image carrying all SKU overlays; bootloader applies exactly one overlay selected by board-ID (never probe-all — probe-all costs boot seconds §28 anti-pattern + risks double-apply regulator double-vote). Chain: source `devices/<sku>/dts/*.dtso` → `dtc` → per-overlay `.dtbo` → `mkdtboimg.py` bundle → `avbtool` hash footer (`dtbo` partition) → `vbmeta` descriptor → bootloader `libufdt` apply → kernel sees merged tree (`/proc/device-tree` + `/sys/firmware/fdt`). Bad overlay must fail closed: bootloader rejects (AVB red-equivalent event + slot stays bootable on previous `dtbo`) or kernel fails safe (framebuffer fallback §5 ch.03, never panic on missing panel/touch).

```bash
set -euo pipefail
SKU=${1:-sdm845-oneplus6}; OUT=out/$SKU; SRC=devices/$SKU/dts
# 1. compile base + overlays (W=1, provenance comments per §13 enforced by lint)
dtc -I dts -O dtb -W no-unit_address_vs_reg -o $OUT/base.dtb $SRC/base.dts
for o in $SRC/*.dtso; do n=$(basename $o .dtso); \
  dtc -I dts -O dtb -o $OUT/$n.dtbo $o; \
  fdtdump $OUT/$n.dtbo | head -30 | tee $OUT/$n.fdtdump-head.txt; done
# 2. overlay lint (CI boot-lint companion: dtbo-lint)
scripts/dtbo-lint.py --src $SRC --out $OUT  # checks: /plugin/ present, fragment target paths exist in base fdtdump, no root-property overwrite, regulator always-on needs justification comment
# 3. bundle (page_size 2048, version 1 — version pinned per bootloader libufdt capability in hw/<sku>/edl.md)
mkdtboimg.py create $OUT/dtbo.img --page_size=2048 $(for f in $OUT/*.dtbo; do echo "--dt $f"; done)
mkdtboimg.py dump $OUT/dtbo.img -b $OUT/dtbo-dump.txt  # Expected: entry count == overlay count, id/rev per board-id-table
# 4. AVB: hash footer on dtbo + descriptor into vbmeta (rollback_index shared with boot, §6)
avbtool add_hash_footer --image $OUT/dtbo.img --partition_name dtbo --partition_size 8388608 --rollback_index $REL_ROLLBACK
avbtool make_vbmeta_image --output $OUT/vbmeta.img --key keys/release.key --algorithm SHA256_RSA4096 --flag 2 \
  --include_descriptors_from_image $OUT/boot.img --include_descriptors_from_image $OUT/dtbo.img
avbtool info_image --image $OUT/vbmeta.img | tee $OUT/vbmeta-info.txt
# Expected: vbmeta-info lists boot + dtbo hash descriptors, rollback_index == release train, flags == 2 (release) / 0 (eng-orange)
# 5. apply-verify without flashing (QEMU + bootloader-stub + on-device dry-run)
scripts/dtbo-apply-check.sh --base $OUT/base.dtb --bundle $OUT/dtbo.img --board-id $SKU --dump-merged $OUT/merged.dtb
fdtdiff $OUT/base.dtb $OUT/merged.dtb | tee $OUT/dtbo-applied.diff  # review artifact per release
```

Expected outputs: `dtbo-dump.txt` entry per board-ID (`id` matches `hw/<sku>/board-id-table.csv` — mismatch fails closed, never best-effort-nearest); `vbmeta-info.txt` shows both descriptors + key-id; `dtbo-applied.diff` shows only intended nodes (regulator/panel/touch per §13 checklist — any `chosen/bootargs` or `/memory` delta = lint FAIL, overlays never touch those); on-device `fastboot flash dtbo` + reboot → `ls /proc/device-tree/soc/...` shows overlay nodes + `dmesg | grep -i ufdt` shows `applied overlay id=<N>` single line (two applied lines = double-apply bug, P1).

| Artifact/check | Owner | Why | Test |
|---|---|---|---|
| `.dtso` provenance comments (§13) | BSP/Kernel | sourceless DT lines are how wrong-regulator ships | `dtbo-lint.py` 0 uncommented |
| `mkdtboimg` id/rev vs board-ID table | BSP/Factory | wrong overlay on wrong SKU bricks panel/touch silently | `apply-check.sh` per board-ID matrix |
| AVB `dtbo` descriptor + rollback | Security/Release | unsigned dtbo = unverified hw config (regulator overvolt path) | `info_image` + rollback-reject test |
| merged-tree `fdtdiff` review | Kernel/BSP | overlay blast-radius visible pre-flash | diff committed per release |
| bootloader `libufdt` apply log | Bootloader | double-apply/missing-apply only visible here | `ufdt applied id=` single line |

Rollback on bad overlay (three layers, tested per release on sacrificial): (1) AVB layer — `dtbo` with bad signature/rollback → bootloader refuses apply, boots with previous-slot `dtbo` + logs `vbmeta-dtbo-reject` event to pstore/misc (test: flash N-1 signed `dtbo` over N release → must refuse, `getvar verifiedbootstate` stays green on old slot); (2) apply layer — overlay fails `libufdt` resolve (target path missing after base-DT bump) → bootloader boots base-DT-only + sets `androidboot.dtbo=missing` cmdline (registry §37 — kernel/userspace degrade: panel fallback framebuffer + `DTBO-MISSING` banner, never panic; test: deliberately broken overlay id on eng → fallback observed over UART); (3) runtime layer — applied overlay probes wrong (panel dead but UART alive §10 row) → `halide-firstboot-check` marks slot unbootable (`misc` + `update_engine` health, ch.09 A/B) and reboots to previous slot within 3 attempts (test: panel-incompatible overlay → auto-rollback without EDL). Overlay downgrade without full-image downgrade is denied (rollback_index shared §6 — split-version boot+dtbo pairs are untestable combinatorially, so they don't exist).

## 41. Long-term ABI pin procedure (symbols.txt, abi.xml diff, KMI enforcement)

GKI promise: kernel module interface (KMI) stable within an LTS generation so vendor modules (`vendor_modules/<name>/` §4) survive stable bumps (§26) without rebuild. Enforcement is mechanical: `symbols.txt` (per-symbol allowlist + owner) + `abi.xml` (libabigail dump of vtables/layouts actually consumed by vendor modules) + `KMI_ENFORCEMENT=1` build flag that fails the build on drift. Any stable bump, toolchain bump (§32), or carried-patch (§27) that moves the ABI trips the gate before HW time is spent. Silent ABI drift that reaches factory is a release-process P1 (factory smoke `modinfo` vs PROVENANCE §24 would catch it late — this gate catches it at commit).

```bash
# 1. generate current ABI artifacts (containerized, same digest as §11 build)
make ARCH=arm64 O=out/$SKU Image.gz modules
scripts/dump-abi.sh --out out/$SKU/abi-current/  # wraps: abidump vmlinux + genksyms per .ko + symbols.txt extraction
# produces: abi-current/abi.xml, abi-current/symbols.txt, abi-current/vermagic.txt, abi-current/modules.order
# 2. diff against pinned baseline (kernel/abi/<lts>/abi.xml + symbols.txt committed)
abidiff kernel/abi/6.6/abi.xml out/$SKU/abi-current/abi.xml > logs/abidiff.txt 2>&1 || true
diff -u kernel/abi/6.6/symbols.txt out/$SKU/abi-current/symbols.txt > logs/symbols-diff.txt 2>&1 || true
scripts/abi-gate.py --baseline kernel/abi/6.6/ --current out/$SKU/abi-current/ --kmi-enforcement 1 | tee logs/abi-gate.txt
# Expected gate output: ABI-UNCHANGED (empty diffs) OR ABI-ADDITIVE-ONLY (new symbols, no layout change, allowlisted) OR ABI-BREAK (nonzero exit + named symbols/structs)
# 3. KMI string + vermagic pin (what modules actually check at load)
cat out/$SKU/abi-current/vermagic.txt  # expect: 6.6.x SMP preempt mod_unload aarch64 (exact string in kernel/abi/6.6/vermagic.pin)
modinfo out/$SKU/modules-staging/lib/modules/*/extra/*.ko | grep -E 'vermagic|depends' | tee logs/modinfo.txt
# 4. blessed-break procedure (only via this MR shape, never drive-by)
# MR must contain: abidiff.txt + symbols-diff.txt + ABI-BREAK-JUSTIFICATION.md (what moved, why unavoidable: upstream-stable commit SHA or erratum + affected vendor modules rebuilt list + factory PROVENANCE note) + Kernel+Arch+Security sign (same quorum as fast-lane §26)
```

Expected outputs: `abi-gate.py` → `ABI-UNCHANGED` on routine bumps (most 6.6.x stable bumps are additive-safe — triage file §26 must still record the gate line); additive exports (new `EXPORT_SYMBOL_GPL` used by a new vendor module) land as `ABI-ADDITIVE-ONLY` + symbols.txt append with owner + `SINCE 6.6.y` tag; any `struct` size/field reorder touching `binder_proc`, `dmabuf`, `drm_gem_object`, `snd_soc_*`, `usb_*_driver`, `mmc_host`, `clk_*`, `regulator_*` (hot structs list in `kernel/abi/6.6/HOT-STRUCTS.txt`) = automatic `ABI-BREAK` regardless of abidiff severity scoring (layout change in a hot struct breaks vendor modules even when abidiff calls it compatible — rule written after one such incident, cited in the file header).

| Artifact | Owner | Why | Test |
|---|---|---|---|
| `kernel/abi/<lts>/abi.xml` baseline | Kernel/BSP | machine-readable KMI truth (human diffs lie) | `abidiff` empty/additive on green builds |
| `symbols.txt` + owner + `SINCE` | Kernel + module owners | every export has a consumer and a removal story (§20 companion) | orphan-export lint (export w/o in-tree/vendor user fails) |
| `vermagic.pin` | Kernel/Release | mismatched vermagic = modules silently refuse at factory (§24 smoke) | `modinfo` vs pin in CI |
| `HOT-STRUCTS.txt` | Kernel/Arch | layout-sensitive structs get strictest gate | any touch → mandatory ABI-BREAK review |
| `ABI-BREAK-JUSTIFICATION.md` | Kernel/Arch/Security | breaks are announced with rebuild list, not discovered at flash | MR quorum + factory note |

Troubleshooting ladder (gate red → resolution order): (1) identify mover (`abidiff.txt` top function/struct + `git log -S <symbol> --oneline` — stable-bump mover → §26 revert-vs-carry policy decides, toolchain-bump mover → §32 codegen note, carried-patch mover → §27 admission checklist item-3 violated, fix patch); (2) classify (additive → allowlist-append + owner, compatible-layout → HOT-STRUCTS check decides strictness, break → blessed-break MR or revert, no third option); (3) rebuild blast-radius (`modules.order` reverse-deps: which vendor modules consume the moved symbol — `grep -r <symbol> vendor_modules/` + `modinfo depends` — unlisted consumer = symbols.txt ownership wrong, fix owner); (4) forward/back compat proof (old vendor `.ko` loads on new kernel for additive case — `insmod --dry-run` + sacrificial boot with N-1 vendor modules where policy allows; break case ships lockstep kernel+modules with rollback_index bump §6/§40 so partial OTA can't split them); (5) baseline promotion (post-release: blessed-break `abi.xml` becomes new baseline with `KERNEL-ABI-v<N>` tag + transparency-repo note ch.09 §17 — baselines move only at releases, never mid-train).

## 42. Kernel panic/OOPS classification runbook (panic strings -> subsystem -> owner -> first log)

Every kernel death on HALIDE (lab or field) gets classified within 24h into subsystem → owner → first-log using this table — unclassified panics age into P0 process findings (the panic isn't the only bug; the untriaged panic is). Source of truth for capture is pstore/ramoops (§30 sizing guarantees the text survived) + `halide-early.service` boot-id linkage (ch.05 §2 — orphan pstore with no boot-id routes to Platform first, not Kernel). Field panics arrive via `support-log-script` bundle (ch.04-adjacent `support-log-script.md` must include `/sys/fs/pstore/*` + `dmesg-ramoops` + `console-ramoops` — bundles without pstore are returned for re-capture before Kernel triage).

```bash
# 1. capture (lab: serial + pstore; field: support bundle — same parse after)
cat /sys/fs/pstore/console-ramoops-0 > /tmp/panic.txt; cat /sys/fs/pstore/dmesg-ramoops-0 >> /tmp/panic.txt 2>/dev/null || true
dmesg -T | tail -100 >> /tmp/panic.txt  # live tail only if device still up (oops-not-panic case)
journalctl -b -1 --no-pager | tail -50 >> /tmp/panic.txt  # systemd adjacency (did userspace already wedge?)
# 2. classify (mechanical first pass — script output is the BUG title prefix)
scripts/panic-classify.py --input /tmp/panic.txt --table kernel/panic-taxonomy.csv --out /tmp/panic-class.json
cat /tmp/panic-class.json  # {"class": "BINDER-USE-AFTER-FREE", "subsystem": "binder", "owner": "Android/BSP", "first_log": "dmesg-ramoops", "confidence": "high"}
# 3. first-log deep dive per class (script prints the exact next command)
scripts/panic-firstlog.sh --class "$(jq -r .class /tmp/panic-class.json)" --input /tmp/panic.txt
# 4. file (labels mandatory — unlabeled panic BUGs auto-assigned to triage queue, not to an owner)
# Title: [PANIC-<CLASS>] <first-oops-line-40-chars> (<sku> <ver> <slot>)
# Labels: PANIC, <SUBSYSTEM>, <OWNER>, needs-bisect? (if stable-bump-adjacent per §26), SMMU-FAULT? (§39), ABI? (§41)
```

Classification table (`kernel/panic-taxonomy.csv` normative — script and humans read the same file; new panic shape = new row + MR, not tribal knowledge):

| Panic/oops signature (regex) | Class | Subsystem | Owner | First log + next command |
|---|---|---|---|---|
| `Unable to handle kernel .* at virtual address` | NULL-DEREF / BAD-PTR | driver named in `pc : [<...>] <sym>+off` | driver owner (§13 DT provenance names them) | `dmesg-ramoops`: `scripts/decode_stacktrace.sh vmlinux` → file:line; `addr2line -e vmlinux <pc>` |
| `Oops: .* [#1] .* PREEMPT SMP` (non-fatal) | OOPS-CONTINUABLE | same as pc-owner | same | `dmesg`: taint flags (`Tainted: G W O` decode — `W`=warned-before (find first WARN), `O`=out-of-tree (which vendor module §20 ledger), `G`=proprietary (taint-source hunt first)) |
| `Internal error: Oops - .*` + `binder` in stack | BINDER-UAF | binder IPC | Android/BSP | `dmesg-ramoops` + `logcat -b crash` container side (both halves — binder deaths span stacks); `binderfs_test` repro |
| `rcu: .* stall detected` / `rcu_sched detected stalls` | RCU-STALL | scheduler/power (usually cpuidle/clk-hold, §38 ladder step 4/5) | Kernel/Power | `console-ramoops`: CPUs-stuck mask → `ftrace cpu_idle` window + `clk_summary` held-vote dump |
| `BUG: workqueue lockup` / `hung_task: blocked for more than .* seconds` | HUNG-TASK | storage (UFS/MMC) or modem-QMI sync path | BSP (storage) / Modem | `dmesg`: `task <name> blocked` holder + `sysrq-w` stack; UFS `err_stats` (§15) or `qrtr` timeout adjacency |
| `DMAR|arm-smmu .* (Unhandled context|global) fault` | SMMU-FAULT | IOMMU master (§39) | §39 master owner | §39 triage (FAR/FSR/CB parse — do not binder-triage an IOMMU fault) |
| `Kernel panic - not syncing: VFS: Unable to mount root fs` | ROOT-MOUNT | storage/AVB/ramdisk (§6/§7) | BSP/Security | `console-ramoops` early lines: `VFS` + `dm-verity` + `avb` state (`verifiedbootstate` §37 — red-state root refusal is policy, not bug) |
| `Kernel panic - not syncing: .* out of memory` + `lmkd`/`oom_reaper` adjacency | OOM-PANIC | memory policy (§34) | Power/Android | `dmesg-ramoops`: `Mem-Info` + `slabinfo` + PSI lines (§34) — foreground-kill = P0 per §34 verification |
| `watchdog: BUG: soft lockup` | SOFT-LOCKUP | CPU-bound driver (IRQ storm, spinlock) | driver owner + Power | `console-ramoops`: locked-CPU + `perf top`-equivalent `stacks`; stormer check `wakeup_sources` + `/proc/interrupts` delta |
| `die_if_kernel_recursion` / `stack guard page was hit` / `Stack overflow` | STACK-OVERFLOW | deep-call driver (usually display/camera ioctl path) | Display/Camera | `dmesg`: `allstacks` + `THREAD_SIZE` audit; 8K-vs-16K stack config note per LTS in `kernel/abi/` |
| `audit: .* avc: denied` storm + `init: .* failed` (userspace death, kernel alive) | NOT-KERNEL (userspace) | sepolicy/init (ch.04 §14 / ch.05 §8) | Platform/Security | `journalctl` + `logcat -b all` (route OUT of kernel queue — kernel-tagged sepolicy BUGs bounced with link here) |

Checklist per panic BUG (triage SLA 24h lab / 72h field): [ ] `panic.txt` + `panic-class.json` attached (no classification without the file pair); [ ] taint decoded + out-of-tree module named (§20 ledger link where `O`/`G` present — proprietary-taint panics reproduce on clean tree before upstream report); [ ] first-log next-command output attached (BUGs that stop at the table without running the next command are returned); [ ] stable-bump adjacency checked (`git log --since=<last-green> --oneline` + §21 bisect ticket filed where adjacent — §26 fast-lane clock starts at classification, not at bisect); [ ] SMMU/ABI cross-tags set where table says so (§39/§41 gates get the BUG link automatically); [ ] duplicate search (`panic-taxonomy.csv` class + `pc` symbol + LTS — 3rd duplicate of a known class escalates the class to P1 pattern-bug with owner paged, per ch.10 §11 flake-vs-pattern discipline extended to panics).

Panic retention + metrics (closure loop — classified panics that vanish into BUG trackers don't fix releases): pstore bundles retained per `kernel/panic-retention.md` (lab: 2 releases full text; field: hashed `pc` symbol + class + LTS kept 12 months, full text 90 days with user consent flag — privacy review with Security, ramoops redaction scan §30 re-run on field bundles before storage); weekly `panic-trend.py` posts class counts + new-class alerts to Kernel standup (new class = new taxonomy row MR within 7 days, owner assigned at standup, not later); release gate adds panic-freedom check alongside §25 `boot-hw` green (dogfood §26 Week-3 + nightly §25 HW: 0 `PANIC-*` BUGs open above P2 on the release SHA, 0 duplicates-unlinked, SMMU-FAULT/ABI-tagged BUGs adjudicated by named gate owners §39/§41 — gate exception needs Arch + QA joint sign with the exact BUG IDs in release notes, same discipline as §20 ledger overdue rule).

```bash
# weekly trend + gate query (CI nightly job, output committed)
python3 scripts/panic-trend.py --since 7d --taxonomy kernel/panic-taxonomy.csv --bugs bugs/panic-*.json | tee logs/panic-trend.txt
# Expected: per-class counts, NEW-CLASS lines (signature with no taxonomy match + suggested regex + first-log hint), top pc-symbol repeaters
grep -c 'NEW-CLASS' logs/panic-trend.txt || echo "0 new classes"
./scripts/kernel-bisect.sh --good <last-green> --bad <first-red> --test panic-class=<CLASS>  # auto-filed where stable-adjacent, §21 wrapper reused
```

| Metric/gate | Owner | Why | Test |
|---|---|---|---|
| `panic-trend.txt` weekly + new-class MR ≤7d | Kernel/QA | taxonomy rot is how the same oops gets mis-triaged for months | standup review log + taxonomy git log |
| pstore retention + redaction (§30 scan) | Security/Kernel | field crash text is PII-adjacent (task names, IOVA) | redaction job green + retention audit |
| release panic-freedom (0 P1/P2 open) | Kernel/Arch/QA | shipping atop an untriaged panic is shipping a known brick path | gate checklist + exception IDs in notes |

## Verification (Phase-1 gate)

- [ ] `Image.gz + modules + dtb` build reproducibly (two builders, same SHAs modulo signatures).
- [ ] Fastboot `boot` reaches systemd login + UART shell on REF-A.
- [ ] `ls /dev/binder* /dev/ashmem`, `zcat /proc/config.gz | grep ANDROID_BINDER` green.
- [ ] Suspend/resume 50 cycles script passes; ramoops preserved on forced crash (`echo c > /proc/sysrq-trigger` in eng only).
- [ ] `qrtr-lookup` + `qmicli --dms-get-ids` green on host (modem alive before Android).
- [ ] `modetest -M msm` shows connector+mode; `evtest` shows touch slots.
- [ ] DT provenance review: zero uncommented-source lines in overlays.
- [ ] Watchdog + resin hard-reset demonstrated on hardware (log + video timestamp archived).
- [ ] Kernel CI `boot-hw-sacrificial` green on the release SHA; stable-triage file filed for the LTS bump.
- [ ] Out-of-tree ledger zero-overdue; boot-timeline CSV archived with stage medians inside budget.

Next: `04-aosp-base-hals.md`.
