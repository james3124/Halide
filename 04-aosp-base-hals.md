# 04 — AOSP Base, Manifests & HALs
**Budget: 90,000 chars · Phases: 0–2 · Owner: Android/BSP · Base: AOSP 14 (up) / 15 (target)**

## 1. Manifest & source pins

```xml
<!-- ~/hybrid/aosp/.repo/manifests/halide.xml (excerpt) -->
<manifest>
  <remote name="aosp" fetch="https://android.googlesource.com/" />
  <default revision="android-14.0.0_r55" remote="aosp" sync-j="8" />
  <project path="device/halide/sdm845-common" name="halide/device-sdm845" revision="halide-14" />
  <project path="vendor/halide/sdm845" name="halide/vendor-sdm845" revision="halide-14" />
  <project path="hardware/halide/power" name="halide/hw-power" revision="halide-14" />
  <remove-project name="platform/packages/apps/QuickSearchBox" />
</manifest>
```

Record exact `rXX` + manifest SHA in `MANIFEST.aosp`. No floating `main`. Lunch: `halide_<sku>-userdebug` (eng only for bring-up, never release).

## 2. Partition & namespace plan

`super` holds `system`, `system_ext`, `product`, `vendor`. HALIDE rules: no changes to `system` core init (keep GSI-compat where possible); device specifics in `vendor` + `device/halide`; Debian-side shims in `system_ext` only if Android container needs them (prefer host-side translation).

SELinux: start from AOSP `sepolicy` + `device/halide/sepolicy` deltas. Every `audit2allow` addition requires comment with bug ID + expiry (upstream or remove).

## 3. Mandatory HALs per SKU (checklist with test)

| HAL | Interface | v1 target | Test |
|-----|-----------|-----------|------|
| Audio | `android.hardware.audio@7.1` + effects | primary output+mic+call | `vts -m VtsHalAudioV7_1Target` subset, `tinymix` dump archived |
| Camera | `ICameraProvider@2.7` (HIDL) or AIDL Camera | 1 rear stills + preview | `vts -m VtsHalCameraProviderV2_7Target`, 20 stills script |
| Lights | `ILight` AIDL | backlight+LED | `dumpsys lights` |
| Sensors | `ISensors@2.1` multihal | accel/gyro/step | `vts sensors`, `dumpsys sensorservice` |
| Vibrator | `IVibrator` AIDL | on/off + amplitude | `dumpsys vibrator` |
| GNSS | `IGnss@2.1` via QMI PDS shim | fix open-sky | `gpspipe`, VTS gnss |
| Power | `IPower@5` + hint sessions | suspend hint, boost | `dumpsys power`, suspend residency |
| Health | `IHealth` AIDL | battery %/current | `dumpsys health` |
| USB | `IUsb` AIDL | gadget ADB+MTP | `dumpsys usb`, host toggle |
| Wi-Fi (vendor) | `IWifi` + supplicant | STA connect | `cmd wifi status`, iperf |
| Bluetooth (vendor) | `IBluetoothHci` | HFP+A2DP | `dumpsys bluetooth_manager`, audio loop |
| RIL | `IRadio@1.6` (rild + libril shim to QRTR) | voice/SMS/data | `dumpsys telephony.registry`, `rild` log, VTS radio subset |
| DRM (Widevine) | L3 only v1 | L3 playback | ExoPlayer L3 sample |
| Keymaster/Gatekeeper | software-backed v1 acceptable | boot + lockscreen | `keystore_cli`, CTS keystore subset |

Camera decision (binding for v1): libcamera on host is reference for stills; Android CameraProvider wraps the same sensor via `external-camera`-style adapter where vendor ISP closed. Document per-sensor quality delta vs stock (no silent claims).

Audio decision: host PipeWire owns card; Android `audio.primary` HAL is a proxy (`libaudio-proxy`) that opens PipeWire streams. Call path: modem PCM → host mixer → earpiece, with Android telephony audio policy slaved to host. Echo reference build per SKU recorded in `audio/<sku>/policy.json`.

## 4. RIL deep-dive (highest risk — read twice)

Stack: modem firmware → QRTR → `rild` + `libril-halide` → `IRadio` → Android Telephony → bridge (ch.07) → ModemManager/NetworkManager on host.

Bring-up order: (1) `qmicli --dms-get-ids` on host (proves modem alive), (2) `rild` starts without crash, (3) `getprop gsm.version.ril-impl` set, (4) SIM state READY (`dumpsys telephony.registry`), (5) manual dial via `am start -a android.intent.action.CALL`, (6) data APN attach. IMS/VoLTE: attempt one carrier; if `ImsService` never registers, document CSFB/3G fallback and move on — do not block Phase 2 on IMS.

Logs: `logcat -b radio`, `rild` verbose (`-l` + `persist.vendor.radio.log_loc`), `qrtr-lookup`, host `journalctl -u ModemManager`. Redact IMSI/IMEI in committed logs.

## 5. Container packaging (Android as LXC system container)

Rootfs = `system+vendor+product` images assembled as LXC rootfs (unsquashed in dev, squashfs/erofs in release). Config excerpt:

```
lxc.include = /usr/share/lxc/config/common.conf
lxc.uts.name = android
lxc.mount.entry = /dev/binder dev/binder none bind,create=dir 0 0
lxc.mount.entry = /dev/ashmem dev/ashmem none bind,create=file 0 0
lxc.mount.entry = /dev/dri dev/dri none bind,create=dir 0 0
lxc.cgroup2.devices.allow = c 10:58 rwm  # binder
lxc.apparmor.profile = halide-android
lxc.selinux.context = u:r:container:s0
```

First-stage init inside container = `/init` from AOSP (not systemd). Host systemd unit `halide-android.service` manages lifecycle; `sys.boot_completed` polled via `getprop` over `lxc-attach`.

## 6. Build & flash (dev loop)

```bash
source build/envsetup.sh && lunch halide_<sku>-userdebug
m -j$(nproc) systemimage vendorimage productimage
# Assemble LXC rootfs + host Debian image (ch.09 for release flow)
fastboot flash super out/target/product/<sku>/super.img
fastboot -w  # dev only; never in release runbook
fastboot reboot
# Expect: host login ≤30s, then:
lxc-attach -n android -- getprop sys.boot_completed  # → 1 within 120s
```

## 7. Failure table (Android-specific)

| Symptom | Check | Fix |
|---------|-------|-----|
| `sys.boot_completed` never 1 | `logcat -b all -d \| grep -i "FATAL\|avc:\|ServiceManager"` | SELinux denial (audit2allow w/ bug ID) or missing HAL service in manifest |
| `No service: radio` | `lxc-attach -- service list` | rild crash; check QRTR + `vendor.rild.libpath` |
| Camera green frames | `dumpsys media.camera` + kernel CAMSS log | ISP format mismatch; force YUV420 + fixed stride to isolate |
| Audio no route | `dumpsys audio`, `tinymix` | proxy not connected to PipeWire; check socket perms + UID map |
| Wi-Fi in Android shows off | `cmd wifi status` vs host `nmcli` | netd shim not synced; restart `halide-netd-bridge.service` |

## 8. Audio proxy HAL design (normative)

`audio.primary.halide` is a thin proxy: it implements the AOSP audio HAL interface but opens PipeWire streams on the host via `/run/halide/audio-proxy` (SOCK_STREAM, per-client credentials checked with `SO_PEERCRED` — only `audioserver` UID inside container may connect).

Stream mapping: Android `primary output` → PipeWire `media.role=Multimedia`; `voice_rx/tx` → `media.role=Phone` with echo-reference (`echo-cancel` enabled per `audio/<sku>/policy.json`); `bluetooth` → host BlueZ looped back (never raw HCI). Sampling: 48kHz fixed internally, resample at proxy boundary (document resampler + measured THD+N delta vs stock in `audio/<sku>/measurements.md`).

`tinymix` baseline: dump all controls at release (`tinymix contents > audio/<sku>/tinymix-baseline.txt`); diff on regression. Call-gain tuning procedure: 5 scripted calls (quiet/street/car/speaker/headset), adjust `call-gains.conf`, re-measure sidetone + echo (double-talk test: both ends speak 10s, no howling). Never ship a gain change without the 5-call log attached to the MR.

Effects: host-side (`easyeffects`-style) preferred; Android `audio.effect` bundle limited to pass-through v1 (no double-EQ stacking — measure frequency response once with pink noise to prove single-EQ).

## 9. Camera provider design (normative)

v1 topology per sensor: kernel CAMSS → host `libcamera` (reference stills path, test with `cam`/`qcam`) → `android.hardware.camera.provider@2.7-halide` adapter that re-exposes the sensor as an Android camera device (EXTERNAL-camera heritage, but wired to libcamera pipeline, not USB).

Capability table per sensor (`camera/<sku>/<sensor>.md`): resolutions, RAW vs YUV, frame durations, flash sync, focus modes, known gaps vs stock (e.g., "4K60 absent v1, 1080p30 guaranteed"). No silent upscaling: if ISP outputs 12MP and stock bins to 12MP with tuning we lack, record MTF-adjacent subjective comparison (5 scenes, 3 reviewers, blind vote) — honesty over spec-sheet parity.

Bring-up ladder: (1) `cam -l` lists sensor, (2) `cam -c1 -C3` stills OK, (3) `qcam` preview 30s no green frames, (4) Android `dumpsys media.camera` lists device, (5) F-Droid OpenCamera still + 1080p30 60s. Green frames → stride/format mismatch (force `NV12` + fixed stride to isolate before touching ISP).

## 10. Sensors multihal + GNSS shim

`android.hardware.sensors@2.1-multihal`: sub-HAL per physical sensor reading host IIO nodes (accel/gyro/mag/pressure/ALS/proximity/step-counter via AP hub where present). Sampling: batch FIFO where hardware supports it (else host-side batching at 5Hz to protect suspend). Each sensor record: vendor string, range, resolution, power draw (from datasheet), on-change vs polling — in `sensors/<sku>/inventory.md`.

GNSS: `android.hardware.gnss@2.1` shim over modem QMI PDS (host `gpsd`/QMI client owns the fix; shim republishes NMEA + `GnssLocation`). Cold-start budget ≤120s open sky; test with `gpspipe -r` + Android GPSTest app side-by-side (same antenna, same fix expected ±5s). AGPS: SUPL server configurable; offline v1 acceptable (document TTFF without data).

## 11. Power/health/USB/lights/vibrator (small HALs, still gated)

- Power (`IPower@5` + hints): `POWER_HINT_SUSTAINED_PERFORMANCE` and `INTERACTION` wired to host `cpufreq`/`devfreq` boosts via `/run/halide/power-hint` (rate-limited; log every hint in debug builds to catch boost storms).
- Health (`IHealth` AIDL): battery %/current/voltage/thermal from host `upower`/sysfs (single source; Android never reads fuel-gauge directly).
- USB (`IUsb` AIDL): gadget function switch proxied to host `configfs` (ADB/MTP/PTP/rndis); host owns role-switch (ch.03 §15).
- Lights: backlight + LED mapped to host `backlight` class + `leds` (Android slider follows host and vice versa — single brightness truth in host).
- Vibrator: amplitude + waveform via host `leds/vibrator` or `input-ff`; test 10/50/100% + call-pattern; record current draw (haptics is a power line item).

## 12. Wi-Fi/BT vendor HALs + coexistence

Wi-Fi (`IWifi` + `wpa_supplicant` overlay): supplicant runs on host (NM owns it); Android `WifiService` gets state via netd-bridge (ch.05 §4), never a second supplicant (two supplicants = roam fights). Record firmware (`ath10k`/`cnss`) version + `iw wlan0 scan` + 8h idle + roam test per release.

BT (`IBluetoothHci`): two options — (a) host BlueZ owns HCI, Android gets HFP/A2DP profiles via bridge (v1 default, ch.07 §4); (b) raw HCI passthrough to container (bring-up only, never release — breaks host audio routing). Coexistence: Wi-Fi/BT antenna sharing table from datasheet + measured 2.4GHz iperf with/without A2DP streaming (record delta; if >30% drop, antenna-tune before camera-polish).

## 13. DRM L3 + keymaster/software-gatekeeper (explicit limits)

Widevine L1 is a non-goal v1 (needs trusted execution + provisioning we don't claim). L3: `android.hardware.drm@1.4` with L3 CDM, verified with ExoPlayer L3 sample (480p sample, no HDCP claims). Keymaster/Gatekeeper: software-backed v1 (`android.hardware.keymaster@4.1` SW + `gatekeeper` SW) — sufficient for lockscreen + keystore CTS subset; hardware-backed (QSEE/TrustZone) is Phase-4 stretch with its own threat review (never half-wire TEE — either fully reviewed or software).

## 14. Sepolicy workflow (no cowboy allows)

1. Build `userdebug`, run full Phase-1/2 scenario set, collect `audit.log`.
2. `audit2allow -p out/.../sepolicy` → proposed rules; each rule gets `BUG:<id> EXPIRY:<date> WHY:<one line>` comment or it is rejected in review.
3. `neverallow` baseline in `device/halide/sepolicy/neverallow.halide` (container breakout, raw persist write, direct gauge access from container).
4. `logs/<sku>-selinux-baseline.txt` regenerated per release; diff must be empty or have per-line justification linked to a bug.

Common denials and correct fixes (not blanket allows): `binder` call missing → add precise `binder_call(source, target)` macro, not `allow * *`; `hal_camera` reading persist → move calibration to vendor file_contexts with read-only label; `rild` QRTR socket → `allow rild qrtr_socket:sock_file { read write }` scoped, not `diag_device` widen.

## 15. Full LXC config + idmap + lifecycle scripts

```ini
# /var/lib/lxc/android/config (release shape)
lxc.include = /usr/share/lxc/config/common.conf
lxc.include = /usr/share/lxc/config/userns.conf
lxc.uts.name = android
lxc.arch = aarch64
lxc.rootfs.path = /var/lib/lxc/android/rootfs
lxc.idmap = u 0 100000 65536
lxc.idmap = g 0 100000 65536
lxc.mount.entry = /dev/binderfs dev/binderfs none bind,create=dir,optional 0 0
lxc.mount.entry = /dev/ashmem dev/ashmem none bind,create=file,optional 0 0
lxc.mount.entry = /dev/dri dev/dri none bind,create=dir,optional 0 0
lxc.mount.entry = /dev/snd dev/snd none bind,create=dir,optional 0 0
lxc.mount.entry = tmpfs dev/socket tmpfs defaults 0 0
lxc.cgroup2.devices.allow = c 10:58 rwm
lxc.cgroup2.devices.allow = c 226:* rwm
lxc.apparmor.profile = halide-android
lxc.selinux.context = u:r:container:s0
lxc.signal.stop = SIGPWR
lxc.start.auto = 0
lxc.start.order = 30
```

`halide-android-prepare` (runs before every start): mounts binderfs if absent, checks `/dev/dri`, seeds `/run/halide/*` sockets with correct perms, verifies image version matches host (`/etc/halide-release` vs container `build.prop` `halide.version` — refuse on major mismatch with banner, never boot mixed versions silently).

`halide-android-health` (every 30s via timer): `getprop sys.boot_completed`, `service check radio`, `service check media.camera`; 3 consecutive failures → `systemctl restart halide-android.service` (counts toward the 3-crash banner rule in ch.05 §2).

## 16. AOSP build targets & dev-loop hardening

`m -j$(nproc) systemimage vendorimage productimage vbmetaimage` then `halide-assemble-lxc` (unsquashed dev rootfs with `adb`+`strace`+`perfetto`; release uses erofs + no adb). `lunch` guard: script refuses `eng` on release branch (CI enforces). `fastboot -w` requires typed SKU confirmation (never scripted blindly).

Vendor-module list (`device/halide/<sku>/vendor_module_list.txt`) enumerates every `.ko` expected in vendor_boot/vendor_dlkm; boot fails closed if a listed module is missing (no silent fallback to different radio behavior).

## 17. Vendor module list enforcement (boot fails closed, ch.04 §16 companion)

`device/halide/<sku>/vendor_module_list.txt` (one `.ko` per line with expected `vermagic` + sha256 of the stable-kABI portion): `halide-android-prepare` (ch.04 §15) diffs loaded modules (`/proc/modules`) vs list before starting the container — missing module = refuse with named-module banner (never boot with different radio behavior silently); extra module = warn + `EXTRA_MODULE` journal (investigated, not ignored — extras mean the build drifted). List changes require BSP + Security sign (a module added is attack surface added). Quarterly `modinfo` dump archived per SKU (params + versions — param drift changes power/radio behavior without code change).

## 18. AOSP version bump procedure (rXX → rYY without breaking the hybrid)

1. Bump `halide.xml` revision in sandbox branch; full `repo sync` + record new manifest SHA (MANIFEST.aosp updated same MR — manifest and code never drift).
2. Netd-call table triage (bridges/netd §2 unknown-call rule): boot container, run `UNKNOWN_CALL` metric query — every hit triaged into the translation table before proceeding (new Android revs add netd calls; untriaged calls fail closed by default-reject, which is safe but may break an app path — triage finds out which).
3. Sepolicy re-baseline: full scenario set → `audit2allow` triage per sepolicy-deltas §4 (new denials expected — new code paths, not regressions until proven).
4. HAL interface version check: AIDL/HIDL version bumps (`@7.1`→`@8.0` class) assessed per HAL (adopt vs pin-old with compat shim + BUG link — pinned olds accumulate as TECH-DEBT with removal dates).
5. Full gate re-run on REF-A (ch.10 allowlist subset + boot-timing + permission-sync ×20 + VPN-leak) before merge — bump MRs skip no gates ("it's just a security patch" is how `boot_completed` breaks for a week).
6. Dogfood Soak: bump rides the next nightly for 48h before release-train inclusion (ch.09 §11 nightly flow).

## 19. Treble / VINTF compliance (the interface contract that survives rebases)

`device/halide/<sku>/manifest.xml` (device HAL manifest: every HAL from §3 with interface version + instance + transport `hwbinder`/`aidl`) + `compatibility_matrix.xml` (framework requirements: min kernel version, required HAL versions, SELinux version, AVB version). `vintf` object assembled at build; `checkvintf` runs in CI (fail = manifest/matrix drift — usually a HAL bump without manifest update, ch.04 §18 step-4 companion). VTS Treble subset (`VtsTrebleVintfTest`) in the ch.10 allowlist (not optional — interface drift breaks OTA across versions: N-1 vendor + N system must at least parse, tested by `checkvintf --check-compat` matrix job in CI per bump MR).

Vendor-interface freeze discipline: HAL major versions frozen per yearly train (exceptions need ADR entry, ch.11 §14 — the ADR names the OTA-compat evidence). `lshal --debug` dump archived per release next to appendix-04A service list (two views of the same truth — binder services + HAL instances agree or the MR explains).

## 20. NNAPI / ML-accelerator position (explicit restraint — accelerators are attack surface + blobs)

v1: CPU/GPU ML paths only (NNAPI service present for API-compat, backed by CPU reference + GPU delegate where Mesa supports — no vendor NPU driver). Rationale committed (revisitable with data, not vibes): NPU stacks are the largest closed blobs in modern SoCs (firmware + compiler + runtime, all opaque — threat-model §5 modem-adjacent reasoning applies: unauditable privileged compute), power story unproven on our scheduler (NPU-vs-GPU efficiency measured never on our tree — claims without measurement barred by perf-footnote lint, ch.10 §12), and no dogfood app in TOP-100 compat requires NPU acceleration (requirement absent → work absent — YAGNI with the matrix as evidence). NNAPI conformance subset runs CPU-backed in VTS (`VtsHalNeuralnetworks*` CPU paths — recorded pass, NPU paths listed `UNTESTED`-styled per ch.07 §11 vocabulary discipline extended). Phase-4 entry conditions (all three, not one): named app need from compat-matrix + vendor driver with auditable interface + power-win measurement on our tree (conditions checked at v1-ship review alongside eSIM undecided-list, ch.07 §19 pattern).

## 21. Per-HAL owner runbooks (sensors/power/health/USB/lights/vibrator specifics)

Each small HAL ships a one-page runbook at `hal/<name>/RUNBOOK.md` (owner named, on-call alias, last-drill date — undrilled runbooks expire after 90 days and block the gate per ch.10 drill rules). Common header: service name (`android.hardware.<x>`), instance, transport, host peer (IIO node / sysfs path / configfs gadget / bridge socket), key props (`ro.hardware.*`, `persist.vendor.*`), and the 60-second smoke (copy-paste commands with expected outputs).

Sensors (`ISensors@2.1-multihal`): per-sensor enable→read→disable sequence (`dumpsys sensorservice` shows handle + rate; `lshal --debug` confirms sub-HAL registration); FIFO batch test (`dumpsys sensorservice | grep -A5 <handle>` max-delay honored); wake-vs-non-wake accounting (wake sensors listed with power note from `sensors/<sku>/inventory.md` §10); failure ladder (no events → IIO node missing? → multihal config `sensors_config.json` handle mismatch? → SELinux `hal_sensors` denial in `audit.log`?); drill: unplug-replug virtual sensor + 100Hz accel 60s (no dropped-batch counter growth).

Power (`IPower@5` + hints): hint injection (`cmd power hint INTERACTION 500` → host `/run/halide/power-hint` log line + `cpufreq` boost observed in `cpupower frequency-info` within 200ms); sustained-performance 10-min soak (skin-temp + throttle-trip log per ch.02 §6 — boost storms caught by §11 rate-limit counter); failure ladder (no boost → hint socket perms? → host governor `powersave` pinned by test rig? → SELinux?); drill: 200 rapid hints (storm test — rate-limiter must hold, counter in metrics proves it).

Health (`IHealth` AIDL): `dumpsys health` vs host sysfs (`/sys/class/power_supply/battery/{capacity,current_now,voltage_now,temp}`) agreement table (±2% capacity, ±50mA current after 30s settle — wider gaps mean dual-read paths have split, P1); charger plug/unplug 10× (health HAL event each time, zero missed); drill: low-battery 5% → shutdown-intent path verified (host owns shutdown call — Android suggests, host decides, documented so nobody inverts it).

USB (`IUsb` AIDL): function switch matrix (none/adb/mtp/ptp/rndis/adb+mtp) driven from host `configfs` — each switch verified both sides (`lsusb` on attached PC + `dumpsys usb` accessory state); role-switch host/device per ch.03 §15 (both orientations, C-to-C + C-to-A); failure ladder (gadget missing → configfs mount? → UDC bound? → bridge `halide-usb` daemon state?); drill: 20 rapid function switches (no UDC wedge — wedge requires reboot = P0).

Lights: slider sweep host 0→100% + Android `cmd lights` readback agreement (single-truth rule §11 — divergence means someone cached); LED (unyellowed: notification LED + charging LED patterns, 5 patterns each verified by video); drill: suspend with LED active (no suspend-block from lights service — wakeup audit §14 catches it).

Vibrator (`IVibrator` AIDL): amplitude sweep 10/50/100% + waveform catalog (click/tick/call-pattern) with current-draw note per §11 (haptics power line: `idaemon` meter reading per pattern); duration accuracy (±10ms on 100ms pulse, measured via accelerometer rig or audio-envelope method documented in runbook); failure ladder (no vibe → `leds/vibrator` node present? → `input-ff` claim conflict with touchscreen? → SELinux?); drill: 5-min call-pattern loop (thermal + driver-stability — worn-motor divergence recorded vs baseline).

## 22. HAL test automation (gated in CI, run on hardware nightly)

Layers: (1) VTS subsets per HAL (§3 table — exact module names pinned in `tests/VTS-PINNED.txt` with AOSP rev; bump procedure §18 updates pins with full re-run), (2) contract tests (bridge-side §15 `halide-android-health` extensions: per-HAL `service check <name>` + property assertions in `tests/hal-contract.sh` — runs on VIRT nightly + HW weekly), (3) soak scripts (camera 20-stills loop §9, audio 5-call §8, sensors 100Hz-hour, vibrator 5-min, USB 20-switch — each emits JUnit XML + metrics lines for the dashboard), (4) fault-injection (kill `rild`/`audioserver`/`cameraserver` once each → container health-check §15 must restart-or-banner within 90s; drop binderfs mount → `halide-android-prepare` refuses with named error, never half-boots).

Scheduling: VIRT nightly (contract + VTS host-runnable subset), HW weekly full (all soaks on sacrificial REF-A + REF-B radio subset), pre-release full+repeat (2× HW runs 48h apart — second run catches thermal/flash-wear ghosts). Results: `tests/results/<date>-<sku>/` (JUnit + `dmesg` tail + `logcat -b all -d` slice + `audit.log` denials diff vs baseline §14). Flake handling per ch.10 §11 (quarantine + BUG, no silent re-green). Coverage gate: every §3 HAL row has ≥1 automated test at each of layers 1–3 (matrix in `tests/HAL-COVERAGE.md` — empty cells fail the Phase-2 gate review; manual-only HALs don't graduate).

Device-lab wiring: tests address units by traveler ID (§17 — `HALIDE-A1`, never "the phone on the left"); flash-before-test records to `hw/flash-log.csv` automatically (operator=`hal-test-runner`); power-affecting tests (vibrator loop, sustained-performance) log ambient + meter calibration ID per ch.10 §8 footnotes (unfootnoted power numbers rejected like unprovenanced DT lines ch.03 §13).

## 23. Vendor-drop integration procedure (new blobs/firmware without breaking the hybrid)

Entry: vendor publishes modem/WCN/camera-firmware/audio-tuning drop (or stock OTA extraction yields new SHAs vs BLOBS.md ch.02 §4). Step 0 — quarantine: drop lands in `vendor/incoming/<sku>-<date>/` (never directly into `vendor/<sku>/` — incoming is untrusted until qualified). Step 1 — inventory: filename/version/SHA256/license/redist-flag table (BLOBS.md format) + binary diff stat vs current (`bsdiff` size + changed-file list — 200MB unexplained delta investigated before boot, not after). Step 2 — static review: strings/entropy scan for new network endpoints or cert blobs (Security eyeball for modem/adsp drops — new QRTR services predicted by comparing `qrtr-lookup` service lists §14 pre/post; surprise services get threat-note before enable). Step 3 — staged boot: sacrificial unit only (traveler §17 role check — dogfood units never first-boot vendor drops), probes in order (rproc states → `qrtr-lookup` diff → `qmicli` IDs → RIL ladder §4 → audio `tinymix` diff vs baseline §8 → camera stills §9 → sensors/GNSS §10). Step 4 — regression sweep: contract tests ( §22 layer 2) + 8h idle power + 1 thermal soak (modem FW changes move power first, features second — power measured before celebrating). Step 5 — promotion: BLOBS.md + BLOB-SHA256.txt updated + `vendor_module_list.txt` re-verified (§17 — FW drops sometimes rename `.ko`) + release-notes entry (version + test IDs + power delta) + BSP + Security sign (module-added = attack-surface-added rule §17 applies to FW too).

Rollback: previous drop retained 2 releases (storage-budgeted in image-size accounting ch.09); `halide-vendor-rollback` fastboot path tested per drop (flash previous + verify `qrtr-lookup` service list restores — rollback that changes the service list without test IDs is a finding). Failed-drop handling: case file pattern from RMA §18 adapted (`vendor/drops/<date>-FAIL.md` with LESSON line — repeated vendor QA misses feed the vendor scorecard §18).

IMS/VoLTE carve-out (explicit, §4 companion): vendor drops advertising IMS fixes get one-carrier validation per ch.07 ladder (blessed carrier only — validating all carriers per drop is unbounded; unblessed carriers stay documented-fallback per §4). IMS regression without blessed-carrier impact ships with a KNOWN-ISSUE line (ch.09 §14 template), not a hold — the hold budget is spent on blessed-carrier breaks.

## 24. HAL interface version-skew handling (old vendor + new system must at least parse)

Skew matrix (CI job `checkvintf --check-compat` per §19 runs all four cells on every bump MR §18): N-system/N-vendor (release shape — full gates), N+1-system/N-vendor (OTA-forward compat — must parse + boot_completed, degraded features allowed only with named-degradation list), N-system/N+1-vendor (factory-ahead — must refuse with banner per §15 version-guard, never half-boot), N-1 archive parse (transparency-repo manifests from two releases back still validate with current `checkvintf` — auditors diff across releases per P3 story). Failure policy: forward-compat cell red blocks the bump MR (OTA ships system ahead of vendor on A/B devices during staged rollout — unparseable skew bricks the update path, not just a test); factory-ahead refusal path tested with mismatched `halide.version` props (banner text asserted in test, not just exit code — confused-factory-operator UX from ch.01 §18 readiness).

AIDL/HIDL freeze discipline (§19 companion with teeth): major-version bumps frozen per yearly train; mid-train bump requires ADR (ch.11 §14) naming OTA-compat evidence from the skew matrix (which cells ran, build IDs, degradation lists). Compatibility shims (old-HAL-behind-new-framework adapters) carry `UPSTREAMING.md`-style entries (interface, direction, removal release — shims without removal dates accumulate into permanent translation bugs; the §20-equivalent ledger for shims lives in `hal/SHIM-DEBT.md` with the same quarterly review + strictly-decreasing-count graph).

## 25. Thermal-throttling HAL contract (power hints meet physics)

Interface: `IPower` hint sessions (§21 runbook) + `IThermal` AIDL (v1 minimal: `getTemperatures` CPU/GPU/battery/skin + `registerThermalChangedCallback`; throttling decisions owned by host `thermald`-class daemon — Android advises via hints, host enforces via cpufreq/devfreq + brightness cap + modem-TX backoff requests through ril-bridge). Severity mapping table (`thermal/<sku>/severity-map.csv`: sensor → thresholds °C → Android `THROTTLING_{NONE,LIGHT,MODERATE,SEVERE,SHUTDOWN}` → host action (boost-deny, brightness-cap %, video-record-block with user message, emergency shutdown below battery-safe curve) — thresholds from ch.02 §6 envelope + panel/battery datasheets, never copied across SKUs (thermal mass differs; copied thresholds throttle wrong or burn).

Validation: sustained-performance 15-min soak (CPU+GPU load + 1080p record + LTE iperf — the concurrent worst case from ch.03 §13 interconnect tests) with skin-temp probe + `thermal` callback log + host freq traces; pass = no `SEVERE` before 10 min at 25°C ambient + orderly throttle (freq steps down, no hard shutdown, user-visible "Cooling down" notice before frame drops — silent throttling that looks like jank fails UX review). Throttle-vs-jank arbitration (§14 frame-join companion): traces during soak tagged with thermal severity so jank triage distinguishes driver bugs from physics (fence-wait + SEVERE = expected, fence-wait + NONE = bug). Calibration note honesty (ch.10 §8 pattern): ambient recorded per soak, meter/thermal-camera calibration IDs footnoted — unfootnoted thermal numbers rejected like unfootnoted power.

## 26. Biometric/peripheral HAL staging (fingerprint/face/NFC wait their turn — visibly)

Status (explicit so nobody builds on assumptions): fingerprint/face-unlock/NFC-HCE are Phase-4 stretch — v1 lockscreen is PIN/password via software gatekeeper (§13) + host Settings ownership (ch.05 §11 Calls/Chats pattern extended: host owns lockscreen, Android keyguard suppressed via overlay like SystemUI §6 ch.06). Staging packets (`hal/<bio>/STAGING-<date>.md`, informational v1): sensor inventory (part number, SPI/I2C path, TZ-driver dependency named — TrustZone-dependent sensors flagged `TEE-BLOCKED` with the threat-review precondition from §13 restated: either fully reviewed TEE or software, never half-wired), host-side probe evidence (`evtest`/IIO node or documented absence — absent-sensor packets stay one line, no speculation novels), Android interface target (AIDL `IBiometrics` version pinned at staging time + framework overlay keys reserved so v1 overlays don't collide later).

Entry conditions (all three, NNAPI-pattern §20 restated for biometrics): named story need (P1/P3 demand with counts — "enterprise deployer requires fingerprint for 200 units" outranks "flagships have it"), driver with auditable interface (closed TEE blobs get the §23 vendor-drop quarantine + threat-note before any enable — biometric templates in opaque TEE with unaudited host API is a Security veto, stated in advance so schedule planners hear it early), power/suspend proof (sensor idle current in budget table ch.05 §21 + wake-source audit clean — always-on biometric listeners that halve standby are rejected with the measurement attached). NFC carve-out: NCI probing informational v1 (ch.03 §13 DT note); HCE/payment explicitly out (needs secure-element story + keymaster-hardware §13 — bundled or not at all, never HCE-without-SE half-shipped).

## 27. HAL SELinux-denial triage SLA (denials age like fish, not wine)

New-denial clock (companion to §14 workflow + §22 results archive): any `avc: denied` delta vs baseline appearing in CI/HW results gets a BUG within 48h and a disposition within 14 days (allow-with-§14-comment, neverallow-justified-refusal with code fix, or reverted behavior). Undispositioned denials at 14 days escalate to the weekly blocker review (ch.01 §21 queue accepts `SELINUX-AGE` P0s — silent denial debt is how container breakouts incubate). Baseline regeneration (§14 step 4) requires Security sign listing each delta row with its BUG (blanket "rebaselined" commits rejected — the diff is the review). Eng-build permissive domains enumerated (`permissive <domain>;` lines each carry `ENG-ONLY:` + removal release — a permissive domain present on a release-branch build fails CI `neverallow-eng` check; the check runs on the release branch so eng conveniences can't ride the train).

## 28. HAL ownership rotation & bus-factor rule (runbooks outlive authors)

Every §3/§21 HAL names an owner + a backup (both in RUNBOOK header + `hal/OWNERS.md`): backup performs the drill quarterly (drill log names the performer — owner-only drills prove nothing about succession); owner departure without trained backup triggers the same 90-day succession window as device-maintainer departures (ch.02 §14 pattern — unnamed-successor HALs demote to COMMUNITY-grade support with release-note honesty, never silent orphaning). New-owner onboarding: run the HAL ladder (§4 RIL / §9 camera / §8 audio-5-call as applicable) supervised once, results co-signed — onboarding by reading alone doesn't qualify a hardware owner.

## 29. HAL MR checklist (review gate, one line per rule — all green or no merge)

`TRACEABILITY.csv` row touched (ch.01 §20) · contract test present/updated (§22 layer 2) · `audit.log` delta triaged with BUG (§27 clock) · `vendor_module_list.txt` diff dual-signed if modules move (§17/§23) · `manifest.xml`/`checkvintf` green on all four skew cells (§24) · power note attached for sensor/hint/vibrator changes (§21 runbooks + ch.05 §21 budget) · NO-CHANGE lines justified, never defaulted (RMA-lesson discipline §18 ch.02 applied to HAL MRs).

## 30. Audio effects pass-through certification (single-EQ proof, not promises)

Doctrine (ch.04 §8 restated with certification teeth): exactly one equalizer in the playback chain. Host owns EQ (`PipeWire` filter-chain / `easyeffects`-style per `audio/<sku>/policy.json`); Android `audio.effect` bundle v1 is pass-through (insertion-loss 0dB ±0.5dB, 20Hz–20kHz). Double-EQ stacking (host bass-boost + Android `BassBoost` both active) is the classic mud failure — this section makes it unshippable without measurement.

Certification rig per SKU (`audio/<sku>/measurements.md` normative appendix): loopback capture (3.5mm line-out → USB audio interface, 48kHz/24-bit, interface calibration file committed with serial + cal date; Bluetooth paths measured over HCI-logged SBC/AAC with codec noted — BT measurements without codec label rejected), pink-noise + sine-sweep stimuli (`audio/test-tones/` in repo: 30s pink, log-sweep 20–20k 30s, THD+N 1kHz -3dBFS), three gain points (30/70/100% slider). Metrics per run: frequency response Δ vs bypass (1/3-octave, pass ±1.5dB 100Hz–15kHz, ±3dB edges), THD+N @1kHz (pass ≤0.1% wired, ≤0.5% BT-SBC with codec footnoted), insertion loss (pass-through path 0±0.5dB), resampler check (48kHz-fixed §8 boundary: 44.1kHz Android stream → capture shows no alias images above -80dBFS).

Certification matrix (every cell measured per release, CSV in `audio/<sku>/effects-cert.csv`):

| Path | Android effect state | Host EQ state | Expect |
|---|---|---|---|
| primary out → speaker | all OFF (pass-through) | flat | baseline curve (this IS the reference) |
| primary out → speaker | all OFF | SKU house curve | house curve only (delta = host file, provable by diff) |
| primary out → speaker | BassBoost ON (test) | flat | CERT-FAIL expected (proves test detects stacking — negative control) |
| voice_rx → earpiece | OFF | echo-cancel per policy.json | double-talk 10s no howling (§8 5-call log cites this row) |
| BT A2DP → headset | OFF | flat | codec-noted curve, no second resample (HCI `sample_rate` = 48k or 44.1 consistently, flapping = bug) |
| USB-C headset | OFF | flat | insertion-loss row, bit-exactness spot-check (1kHz tone phase-stable 60s) |

Negative-control rule: the BassBoost-ON row must FAIL response-flatness (if it passes, the rig is deaf — cert invalid, rig fixed before any ship claim). Blessed configurations enumerated (`audio/<sku>/blessed-effects.conf`: exactly `pass-through` v1 + named host presets `flat|voice-clarity|bass-lite`; any other combination shows Settings "Unsupported audio tuning (resets to Flat)" banner, never silent stacking). MRs touching `policy.json`, `call-gains.conf`, resampler, or proxy resample path re-run the full matrix (cert file hash in MR + delta plot; "sounds fine to me" without CSV closed with link here). Regression handling: >1.5dB drift vs baseline → `tinymix` diff (§8) + `policy.json` diff + BLOBS.md audio-drop check (§23 vendor-drop staged-boot audio row) in that order — gain/ tuning drift almost always one of those three, investigated in that order before DSP blame.

## 31. Camera EXIF / orientation discipline (up is up on both stacks)

Problem shape: sensor native orientation (typically landscape 90°/270° mount) + device rotation (portrait user) + front-mirror + libcamera vs Android `CameraCharacteristics.SENSOR_ORIENTATION` disagreement = sideways selfies, upside-down video thumbnails, and gallery apps that "fix" rotation by re-encoding (quality loss + power). Both stacks must agree on one orientation truth per sensor per mount.

Per-sensor orientation record (`camera/<sku>/<sensor>.md` extension, normative): `sensor_native_deg` (0/90/180/270 from datasheet + verified by `cam` still of a plumb-line target — datasheet mount diagrams lie about mirror variants, the target photo proves it), `mount_mirror` (front sensors: `mirror=true` + sample selfie with asymmetric target e.g. printed arrow — arrow direction in file proves mirror handling, not prose), `android_sensor_orientation` (90/270 computed = `(native - device_landscape_offset) mod 360`, formula shown in file with numbers, not just result), `facing` (BACK/FRONT/EXTERNALheritage note §9), `jpeg_orientation_policy` (EXIF tag written by provider, thumbnail rotation matches — verified by `exiftool` on 20-stills loop §9 output, orientation-tag histogram committed: all-6s or mixed-bag = bug).

EXIF writer rules (provider adapter §9): `Orientation` tag always written (never omitted — omitted means every viewer guesses differently); `PixelXDimension/YDimension` describe stored (not display) geometry; `Make/Model` = `HALIDE <sku>` + `Software` = build ID (bug-report stills self-identify; stills without build ID rejected from quality votes §9 blind-vote protocol extended — unidentified samples don't vote); GPS tags only with user location consent (host consent state queried at capture — consent-off writes no GPS IFD at all, not zeroed-coordinates (zeroed = false location in the ocean, worse than absent)); timestamp = container wall-clock at shutter-close (Δ vs host clock ≤2s per ch.03 §36 time-vote — EXIF timestamps from unvoted clocks drift across DST/suspend and corrupt burst ordering).

Orientation test battery (per release, per sensor, in `tests/results/`): plumb-line still (vertical edge within ±1° of image vertical after viewer auto-rotate — measures capture+EXIF+viewer chain end-to-end), 4-rotation burst (device 0/90/180/270, same target — all four auto-rotate upright in Phosh `loupe` + Android Photos-equivalent; any sideways survivor names the broken layer via tag dump), front-mirror selfie (asymmetric target reads correctly mirrored — text readable in mirror-correct direction, documented which), video rotation (60s 1080p30 at 0° + 90° start — rotation metadata track present, mid-record rotation handled by lock-workaround ch.06 §9 path with banner, never half-rotated file), host-vs-container agreement (libcamera `qcam` still + Android still same scene — both upright, EXIF tags diffed field-by-field, disagreement = P1 against the adapter, not "viewer difference"). Failure ladder: sideways everywhere → `SENSOR_ORIENTATION` formula wrong (recompute with numbers shown); upright in one stack only → that stack ignores EXIF (overlay/config flag, not sensor — `config_statusBarComponent`-class overlay audit ch.06 §6 pattern); correct stills + wrong video → container rotation-metadata path (not sensor — don't touch ISP for a muxer bug).

## 32. Sensor batch / FIFO power tuning (wake the AP like it costs money — it does)

Doctrine: every milliamp of sensor idle current is in the suspend budget (ch.05 §21 budget table carries per-sensor lines fed by this section). Two mechanisms: hardware FIFO batching (sensor batches samples, AP sleeps, driver drains in bursts) vs host-side batching at 5Hz (§10 fallback). Hardware FIFO always preferred where present (5Hz host polling costs a full AP wake 5×/s ≈ 8–15mA sustained on REF-A — measured in `sensors/<sku>/power.md`; polling is the fallback with the cost attached, not a silent default).

Per-sensor batch record (`sensors/<sku>/inventory.md` extension — columns added to §10 inventory): `fifo_depth` (events, from datasheet + verified by `dumpsys sensorservice | grep -A5 maxDelay` + driver `batch()` success at max-delay), `max_batch_s` (measured longest drain interval without `dropped-batch` counter growth — claimed 10s FIFOs that drop at 6s recorded at 6s with the counter log), `wake_vs_nonwake` (wake sensors named with power note — wake accel for step-detect vs non-wake for rotation-vector; wake-sensor additions need the §21 runbook power sign), `drain_current_ma` (meter delta batch-on vs batch-off during 1h static-on-table test, calibration-footnoted ch.10 §8), `host_poll_hz` (only for non-FIFO sensors: 5Hz default, rationale per sensor or batched-lower with aliasing note — step-counter at 1Hz undercounts stairs, measured once, written down).

Tuning procedure per SKU (sacrificial, airplane-mode, screen-off, same ambient footnote honesty): (1) baseline suspend 8h sensors-off (deep-sleep residency ≥95% §8 ch.03 — proves bench clean), (2) enable one sensor at a time at game-rate (50Hz) non-batched 1h (current delta = worst case), (3) enable max-batch 1h (delta = best case; win = row 2 − row 3, must be ≥30% for FIFO to justify driver complexity — else document `FIFO-NOT-WORTH-IT` with numbers and take host-batching), (4) all-sensors dogfood profile 8h (accel+gyro batch-max + ALS/prox on-change + baro 1Hz — overnight drain ≤3%/8h REF-A target, table in `sensors/<sku>/power.md` with per-sensor attribution so the hog is named, not averaged away). Batching correctness tests (function before power): FIFO overflow injection (shake-table 100Hz accel 60s at max-batch — `dropped-batch` counter 0; drops mean watermark IRQ late — driver `batch_timeout` shortened with before/after counters, not "sensor too fast"), wakeup-accounting (wake sensor fires with screen-off → `wakeup_sources` names it §8 ch.03 audit cross-check — unnamed wakes are misclassified non-wake sensors, P1), timestamp integrity (batched events carry hardware timestamps with <2ms jitter vs host `CLOCK_BOOTTIME` at drain — jitter above breaks rotation-vector fusion and step cadence; jitter histogram per release).

Multihal config (`sensors_config.json` handle map §21 runbook companion): every handle's `maxDelayUs`/`fifoReservedEventCount` match the measured rows above (config claims without measurement flagged like datasheet backlight curves ch.06 §11 — `measured:false` amber). MRs touching batch timeouts, watermark IRQs, `sensors_config.json`, or AP-suspend governor re-run the 1h single-sensor pair (rows 2–3) minimum + overnight on release-train weeks (power regressions ride the train only with numbers, per §18 bump discipline extended to sensor MRs).

## 33. GNSS week-number rollover / time-integrity handling (never trust the sky's calendar blindly)

Background: GPS week counter (10-bit legacy / 13-bit CNAV-adjacent depending on constellation/receiver) rolls over (1024-week/8192-day cycles; GLONASS/Galileo/BeiDou have their own epochs — modem firmware handles the arithmetic, but closed firmware has shipped rollover bugs that step the fix date by 19.6 years and poison any consumer that trusts GNSS time). HALIDE posture: GNSS position trusted conditionally, GNSS time never trusted alone (ch.03 §36 time-vote: GNSS is one of three voters, trusted only with ≥4 SV + fix-valid, outvotable by NTP+RTC always).

Rollover test battery (per modem-firmware drop §23 + yearly regardless — rollover bugs hide for years then bite on the epoch date): simulated-time injection (lab GNSS simulator or recorded-IQ replay at rollover±7d: fix date correct within ±2s of simulator truth, `gpspipe -r` RMC date field asserted programmatically — human eyeballing NMEA dates misses off-by-1024-weeks at a glance because day/month look plausible); live-sky sanity (open-sky fix side-by-side host `gpspipe` + Android GPSTest §10: both dates match host NTP date (Δ≤1 day — day-level assert catches 19.6-year steps with zero flakiness); modem-firmware version pinned in test record (rollover behavior is firmware-version-specific — test without version is anecdote); AGPS-off cold start included (SUPL-provided time can mask a receiver rollover bug — offline path tested explicitly per §10 offline-acceptable rule, with TTFF logged both paths).

Time-integrity firewall (provider shim §10 + time-vote §36 ch.03): NMEA/RMC date parsed defensively (year <2000 or >2040 → `TIME-UNTRUSTED` + position still delivered with `time_valid=false` flag to Android `GnssLocation` (position without poisoned time — navigation works, clock doesn't jump); `HALIDE-GNSS-TIME-REJECT` metric counts events (dashboard alert >0/week pages modem owner — rollover-bug-shaped traffic is never background noise); `dumpsys location` + host `/run/halide/gnss.nmea` both carry the validity flag (single truth — container never sees trusted-time the host rejected). QMI PDS time-uncertainty honored (uncertainty >100ms → untrusted vote regardless of SV count — high-uncertainty fixes during spoofing/jamming trials must not step the clock).

Spoofing/jam-adjacent honesty (v1 scope: detect-and-degrade, not anti-spoof): sudden >1km jump with HDOP<2 + time-step >10s co-occurring → `GNSS-SUSPECT` journal + Android `GnssStatus` constellation-blacklist hint logged (not auto-remediated v1 — remediation is Phase-4 with its own threat review; v1 promises honest flags, not resistance). Dogfood fleet logging (P3 story adjacency): weekly `TIME-UNTRUSTED` + `GNSS-SUSPECT` rates per device-week (same denominator discipline as GPU hangs ch.06 §19 — "rare" with a denominator). Vendor-drop tie-in: modem drops re-run rollover-battery step (§23 staged-boot probes gain a rollover row — FW changelogs rarely confess calendar bugs, the battery finds them).

## 34. Health HAL battery-curve modeling (percentages are a model — ship the model)

Doctrine (§11 single-source restated with modeling depth): host reads the fuel gauge; Android `IHealth` republishes. The number on screen is a model (voltage + coulomb-count + temperature + age), not a measurement. This section makes the model explicit, versioned, and testable — "battery % wrong after update" becomes a diffable model change, not a vibe complaint.

Model file per SKU (`power/<sku>/battery-curve.json`, normative, versioned `model_vN`): open-circuit-voltage table (12+ points SOC↔OCV from cell datasheet or gauge characterization — source-tagged `DATASHEET`/`MEASURED`; `MEASURED` requires 0.05C discharge trace with rig photo + meter cal ID), full-charge-capacity (`design_mah` + `learned_fcc_mah` + learn date — learned FFC drifts with age; dogfood units report quarterly, fleet median drift published in release notes power section), temperature derate (capacity ×0.94 at 0°C-class points per cell spec — cold-weather shutdowns at "20%" are derate-table bugs, fixed here not in the UI), internal-resistance vs SOC (for voltage-sag under transmit burst — modem TX + flash-LED + vibe concurrent sag test asserts no shutdown above 15% indicated), shutdown-voltage (hard cutoff + 200mV hysteresis — flapping power-on/off at 1% means hysteresis wrong, P1), age-compensation (`cycle_count` → capacity scale; 500-cycle 80% anchor from spec with fleet-learned override path).

Agreement + calibration tests (§21 health drill extended to modeling): `dumpsys health` vs sysfs agreement table (±2% SOC, ±50mA after 30s settle — persistent bias = model offset, fixed in curve file with version bump, never by UI fudge factor); 0–100–0 loop (lab supply + load, 0.2C, one full cycle per release-train: indicated vs coulomb-truth max error ≤3% mid-range, ≤5% below 20% — error plot committed, shape matters more than max (knee mis-model at 15% causes surprise shutdowns; knee error >3% blocks train)); thermal chamber spot (0°C + 40°C discharge to cutoff — derate table validated, shutdown orderly with `low-battery → shutdown-intent` path §21 firing before hard cutoff, host-decides rule preserved); gauge-learn audit (quarterly `FCC-learned` vs design per traveler §17 — outlier units (>15% below fleet median at <200 cycles) flagged `BATTERY-SUSPECT` for RMA battery-track ch.02 §18 case files, not averaged into the model).

Update discipline: curve-file changes carry `model_vN→vN+1` + error-plot delta + 0–100–0 re-run (same bar as audio cert §30 — battery % changes without the loop CSV closed with link here); OTA ships new curves with `learned_fcc` preserved across update (wiping learned capacity on update causes post-OTA "battery worse" reports — `halide-android-health` §15 asserts learned-FCC persistence post-slot-switch, tested in the §30 ch.03 OTA-crash-preservation sequence extended to battery state); release notes carry `battery model vN (FCC fleet median X mAh, ΔY vs vN-1)` (same figures-with-claims rule as composer numbers ch.06 §21).

## 35. USB gadget function matrix (which combos, tested states — the host owns the port)

Ownership (ch.04 §11 + ch.03 §35 companion): host `configfs` owns UDC bind + function composition; Android `IUsb` (§21 runbook) is a state mirror + user consent surface (role/function requests from container validated against this matrix — unlisted combos refused with `USB-COMBO-UNSUPPORTED` + metric, never passed to configfs to wedge the UDC). v1 function set: `none adp mtp ptp rndis adb adb+mtp adb+ptp` (9 states; `midi`/`eem`/`ncm` explicitly out v1 with removal-of-exclusion condition named: named-music-app need + UDC-driver `f_midi` validation on sacrificial — YAGNI per §20 NNAPI pattern).

Matrix (every cell tested per release on REF-A + radio-subset REF-B, results `hw/<sku>/gadget-matrix.csv`; UDC-wedge anywhere = P0 per §21 20-switch drill):

| Gadget state | PC enumerates (`lsusb`) | `dumpsys usb` mirror | MTP/PTP browse | ADB auth state | Notes |
|---|---|---|---|---|---|
| none (charging only) | single charge-only config | `UNCONFIGURED` | n/a | offline | suspend-clean (no wakeup source, §8 audit row) |
| adb | 1 adb iface | `ADB` | n/a | `device` post-auth | auth keys host-provisioned (never container-writable persist — neverallow §14) |
| mtp | MTP iface | `MTP` | 100-file browse + 1GB xfer CRC-ok | n/a | xfer 1GB with CRC (silent-truncate bugs caught by hash, not size) |
| ptp | PTP iface | `PTP` | `gphoto2 --get-all-files` 10 raws | n/a | EXIF orientation §31 spot-check on pulled files (chain test) |
| rndis | RNDIS + DHCP | `RNDIS` | n/a | n/a | firewall default-deny (tether-surface rule §35 ch.03 — `iptables -L` dump per test) |
| adb+mtp | both ifaces | `ADB+MTP` | browse + `adb shell` concurrent | `device` | concurrency 10 min (function-flap counter 0) |
| adb+ptp | both ifaces | `ADB+PTP` | pull + shell concurrent | `device` | same soak |

Switch rules: function switch via host daemon only (`halide-usb` serializes: unbind → compose → bind with 2s settle + `UDC-WEDGE` watchdog (bind-absent >5s → unbind-all + rebind-previous-known-good + journal + metric — automatic, counted, never manual-unplug-recovery-as-procedure)); 20-rapid-switch drill (§21) asserts wedge-counter 0 + `lsusb` VID/PID stable + container mirror agrees within 3s each switch (mirror lag histogram archived — lag >3s means bridge, not UDC, triage accordingly); role-switch (host/device per ch.03 §35 cable matrix) interlocked with gadget state (role→host tears down gadget first — teardown-before-role ordering asserted in `dmesg` order log, reversed order wedges DWC3 on SDM845 silicon, root-caused once, ordering test committed).

Consent + lockdown (permission-atomicity doctrine adjacency): PTP/MTP auto-grant only to unlocked-device sessions (locked → `USB-CONSENT-REQUIRED` notification on host lockscreen + container mirror `UNCONFIGURED` until host unlock — lockscreen-bypass-via-USB-attempt test in security suite: locked + `adb shell` must stay `unauthorized`, MTP must not enumerate files — failure = P0); eng builds allow `adb root` (bannered), release never (CI asserts `ro.debuggable=0` + `adb root` → `adbd cannot run as root in production builds` string in test, not just exit code — confused-operator UX rule ch.01 §18). Accessory-mode (AOA) out v1 (unlisted → refused per default-reject, logged `UNKNOWN_CALL`-style for demand measurement like HDR `FORMAT_FUTURE` ch.06 §13 — demand counted, scope not widened).

## 36. Audio HAL latency budget table (MMAP vs legacy, frames, periods, underrun counters)

Doctrine (§8 proxy restated with numbers): every millisecond of audio latency is budgeted, measured, and owned. Host PipeWire owns the card; `audio.primary.halide` proxy adds a fixed, measured hop (never "negligible" — the hop is in the table with a number). Two data paths: MMAP (exclusive/shared, low-latency, `AAudio`/`Oboe` path) and legacy (`AudioTrack`/`AudioFlinger` mixer, deep-buffer). v1 ships both (legacy for compat, MMAP for instrument/voice/game need); the budget table proves which path meets which need.

Per-SKU budget file (`audio/<sku>/latency-budget.csv`, normative, versioned per release): columns `path,sample_rate,frames_per_burst,period_count,period_frames,kernel_buf_ms,hal_proxy_ms,dsp_host_ms,total_roundtrip_ms,underrun_budget_per_hour`. Reference REF-A (SDM845, 48kHz fixed §8) baseline — copy shape, re-measure per SKU, never copy numbers:

| Path | Rate | Burst/Period | Periods | HAL hop | Host mix | Total out | Round-trip | Budget |
|---|---|---|---|---|---|---|---|---|
| MMAP exclusive (`AAudio EXCLUSIVE`, `mmap=yes`) | 48k | 192-frame burst | 2 bursts | 2.0ms | 4.0ms | 8.0ms | 16–20ms | ≤1 underrun/h |
| MMAP shared | 48k | 192-frame burst | 4 bursts | 2.0ms | 8.0ms | 16.0ms | 28–34ms | ≤2 underrun/h |
| Legacy `FAST` (`AudioTrack fast`, mixer) | 48k | 256-frame period | 4 periods | 2.0ms | 12.0ms | 26.7ms | 45–60ms | ≤4 underrun/h |
| Legacy `DEEP_BUFFER` (media playback) | 48k | 1024-frame period | 4 periods | 2.0ms | 40.0ms | 128ms | 200–260ms | 0 underruns (buffered) |
| Voice `VOICE_CALL` (`voice_rx/tx`, echo-cancel on) | 16k WB / 48k int | 160-frame (20ms) | 4 | 3.0ms (EC) | 10.0ms | 40ms mouth-to-ear budget 150ms | — | 0 drops >40ms gap |
| BT A2DP SBC software (`§40` companion) | 44.1k | 512-frame | 6 | 2.0ms | 60ms codec+air | 180–220ms | — | codec-noted, no flap |

Computation rule (shown in file, not just result): `period_ms = period_frames / sample_rate * 1000`; `total_out_ms = period_ms * period_count + hal_proxy_ms + dsp_host_ms`; round-trip = out + in + host loopback (loopback-cable rig §30 cert rig reused — same USB interface + cal file, new stimulus: 1kHz ping + correlation). Proxy hop measured by `TRACE` timestamps (`audio-proxy` logs `t_enter/t_exit` per burst in debug builds — p50/p99 per path in metrics, p99 > budget = P1 even if p50 green).

Shell excerpts (60-second smoke, copy-paste from RUNBOOK header §21):

```bash
# 1. Which path is active + mmap state
lxc-attach -n android -- dumpsys media.audio_flinger | sed -n '1,80p'
# 2. Underrun / dropout counters per thread (the scoreboard)
lxc-attach -n android -- dumpsys media.audio_flinger | grep -Ei 'underrun|overrun|drop|mmap|frames|sampleRate|hal latency'
# 3. Proxy hop histogram (host side, debug builds)
journalctl -u halide-audio-proxy -S -30min | grep -E 'path=|p50|p99|underrun' | tail -20
# 4. Burst/period truth from HAL (not policy prose)
lxc-attach -n android -- dumpsys media.audio_policy | grep -Ei 'mmap|primary|fast|deep|voip|burst' | head -30
# 5. AAudio self-test (MMAP reachability per path)
lxc-attach -n android -- /vendor/bin/aaudio_loopback -t60 -pEXCLUSIVE 2>&1 | tail -15
```

Expected outputs (asserted in `tests/hal-contract.sh` layer-2 §22, strings not just codes):

```
# dumpsys media.audio_flinger (excerpt, REF-A golden — SKU files diff against this shape):
Output thread 0xec11... (type FAST): SampleRate 48000, Format PCM 16-bit, Channels 2
  Normal frame count 256, Fast frame count 256, mHalfBufferSize 512
  HAL latency 12ms, In-flight frames 1024, Underruns 0, Overruns 0
MMAP thread: burst 192 frames, exclusive YES, state RUNNING, xrun count 0
# aaudio_loopback:
Loopback result: roundTrip 18.4ms mean, 21.1ms p99, xruns 0/60s — PASS (EXCLUSIVE budget ≤20ms mean)
# audio-proxy journal:
path=MMAP-EXCLUSIVE p50=1.8ms p99=2.6ms underruns=0 paths_active=2
```

Underrun-counter discipline (counters are release gates, not debug trivia): `Underruns/Xruns/dropped-batch` read at start and end of every soak (§22 layer-3: audio 5-call §8, 60-min music MMAP-shared, 10-min `FAST` game-tone): delta 0 for `DEEP_BUFFER`/voice, ≤budget-row for MMAP/FAST (table above). `dumpsys media.audio_flinger` snapshot pair archived per soak (`audio/<sku>/xrun-<date>.txt`); dashboard metric `HALIDE-AUDIO-XRUN` per path per device-week (same denominator discipline as GPU hangs ch.06 §19 — "rare" with a denominator). Proxy-restart resets counters (audioserver kill fault-injection §22 layer-4 must note reset — post-restart 60s excluded from rate with the exclusion logged, never silently).

Failure table (audio-latency-specific, §7 companion):

| Symptom | Check | Fix |
|---------|-------|-----|
| MMAP `EXCLUSIVE` falls back to `SHARED` | `dumpsys audio_policy \| grep mmap`; proxy `exclusive_busy` log | host stream held by another client (Settings preview tone?) — serialize test; if persistent, `policy.json` exclusive-allowlist wrong |
| p99 proxy hop >4ms (budget 2ms) | `journalctl -u halide-audio-proxy`, host `powertop`/governor | host governor `powersave` pinned or EC on wrong path — unpin per §25 boost, move EC to voice path only |
| `FAST` underruns >4/h, p50 fine | `audio_flinger` in-flight frames vs period math in budget CSV | period_count too low for SKU DDR latency — bump 4→6 periods with MR + re-cert §30 matrix row (never ship period bump without insertion-loss re-run) |
| Round-trip 2× budget, all counters 0 | resampler path (§8 48k-fixed): 44.1k stream double-resampled | pin app to 48k in test + fix proxy `sample_rate` clamp; $44.1k$ alias-row §30 resampler check must also be red — if green, rig deaf per §30 negative-control rule |
| Voice gaps >40ms, no xrun | `voice_rx/tx` EC `echo-cancel` hogging (§8 `policy.json`) | EC frame 20ms vs 10ms mismatch — align to 20ms with double-talk 10s re-test (howling = EC off, gaps = EC late — distinguish before tuning gains) |

Update discipline: any change to `policy.json`, `call-gains.conf`, PipeWire quantum, proxy burst size, or governor hint (§21 power runbook) re-runs: loopback 60s per path + xrun pair + §30 insertion-loss row (latency and EQ share the same wire — touching one re-proves the other). Budget CSV hash in MR; >2ms drift vs baseline names the hop (kernel/host/HAL) with `TRACE` evidence — "OS update made audio slower" without the hop named is closed with link here.

## 37. Camera HAL3 pipeline contracts (request/response, stream combos per SKU, flush/drain timing)

Doctrine (§9 adapter restated as contract): the `CameraProvider@2.7-halide` adapter speaks HAL3 (`capture_request` → pipeline → `capture_result` + buffers) to the framework and libcamera requests to the host. The contract is the translation between the two queuing disciplines — depth, lifetime, and flush semantics written down per SKU, tested per release. No silent queue-depth tuning ("fixed jank by bumping buffers" without the combo table updated = reverted on sight).

Pipeline contract per sensor (`camera/<sku>/<sensor>-pipeline.md`, normative): `hal3_pipeline_depth` (max in-flight `capture_request`s, REF-A 8 — libcamera `Request` queue matched 1:1, deeper HAL3 queue than libcamera backlog = head-of-line stall, measured once with `systrace` camera slice), `request_lifetime_ms` (shutter→result p50/p99 at 1080p30, REF-A 33/55ms; still-capture 12MP 180/350ms), `buffer_manager` (gralloc `HAL_PIXEL_FORMAT_YCbCr_420_888` + fixed stride §9 — stride formula `stride = ALIGN(width,64)` shown with numbers per resolution, green-frame root cause §7 cross-ref), `partial_result_count` (1 v1 — partials>1 deferred to Phase-4 with framework-overlay flag named), `reprocess` (OFF v1 — `YUV_REPROCESSING`/`PRIVATE_REPROCESSING` return `NOT_SUPPORTED`, tested, not assumed).

Stream-combination table per SKU (every row constructed + held 30s + still-captured in release gate; unlisted combos return `NO_SUCH_DEVICE`/graceful `configureStreams` failure with `CAMERA-COMBO-UNSUPPORTED` metric, never HAL crash — crash on unlisted combo = P0):

| Combo | Streams | Max duration | Expect |
|---|---|---|---|
| Preview + still (default) | `1080p30 YUV preview` + `12MP JPEG still` | still ≤350ms stall, preview ≤2 dropped frames | 20-stills loop §9 green |
| Preview + record (video) | `1080p30 preview` + `1080p30 record (encoder)` | 60s hold, `dropped_frame_counter` 0 | §9 60s gate |
| Preview only (low-light) | `720p30 YUV` + 3A-converged | 30s, exposure settle ≤2s | ALS-linked AE note §41 lux row |
| Still only (max-res) | `12MP YUV + JPEG` | single-shot ≤500ms | MTF-vote sample source §9 |
| Front (selfie) | `1080p30 YUV` + `8MP still` mirror=true | mirror-correct §31 | asymmetric-target check §31 |
| EXPLICITLY OUT v1 | `4K60`, `60fps+HDR`, `3-stream + reprocess` | — | refused with metric (demand counted per `FORMAT_FUTURE` pattern ch.06 §13) |

Flush/drain timing (HAL3 `flush()` + `close()` are lifecycle, not hints — app-switch/kill/crash-OTA paths from §30 ch.03 cross-ref): `flush()` completes ≤500ms (in-flight requests returned with `ERROR_REQUEST_ABORTED`, buffers freed, libcamera `stop()` joined — `flush()` that blocks on a stuck ISP (observed 8s on early SDM845 FW) gets the watchdog: 600ms timeout → `CAMERA-FLUSH-TIMEOUT` journal + force `streamOff` + metric, never ANR the dialer-over-camera); `configureStreams` (re-config) ≤800ms; `close()` ≤300ms with zero leaked gralloc buffers (`dumpsys meminfo cameraserver` delta 0 post-close, asserted). Tested by fault-injection (§22 layer-4 `cameraserver` kill + rapid app-switch script `tests/camera-flush.sh`: 50 open→capture→flush→close cycles, 10 mid-exposure kills — leak/timeout counters 0).

Shell excerpts:

```bash
# 1. Provider + device enumeration (HAL instance truth)
lxc-attach -n android -- lshal --debug | grep -i -A2 camera
lxc-attach -n android -- dumpsys media.camera | sed -n '1,120p'
# 2. Characteristics dump (per-sensor checklist input — full dump archived)
lxc-attach -n android -- dumpsys media.camera | grep -Ei 'SENSOR_ORIENTATION|LENS_FACING|SCALER|STREAM_CONFIGURATION|SYNC_MAX_LATENCY|REQUEST_PIPELINE_DEPTH' | head -60
# 3. Active combo + in-flight depth during 1080p30 record
lxc-attach -n android -- dumpsys media.camera | grep -Ei 'active|stream|width|height|fps|inflight|pending|dropped|error' | head -40
# 4. Flush timing probe (host + container correlated)
time lxc-attach -n android -- cmd media.camera flush 0 & journalctl -u halide-camera-adapter -S -2min | grep -E 'flush|capture_abort|streamOff|TIMEOUT' | tail -10
# 5. Buffer-leak check after close
lxc-attach -n android -- dumpsys meminfo cameraserver | grep -Ei 'gralloc|Gfx|total' | head -10
```

Expected outputs:

```
# lshal:
android.hardware.camera.provider@2.7::ICameraProvider/halide_0 (hwbinder, threadpool 4)
# dumpsys media.camera (excerpt golden):
Device 0 (BACK): SENSOR_ORIENTATION 90, REQUEST_PIPELINE_DEPTH 8, SYNC_MAX_LATENCY 0 (per-frame)
  StreamConfiguration: [1920x1080 YUV 30fps] [4000x3000 JPEG] maxInFlight 8
Active session: streams 2, inflight 3, pending 0, dropped 0, errors 0
flush(0): completed 212ms, aborted 3, buffers freed 6 — OK
# meminfo post-close:
Gralloc 0KB delta (pre 12MB / post 12MB baseline) — no leak
```

Camera-characteristics dump checklist (every field verified per sensor per release, `camera/<sku>/<sensor>-chars.md` with `dumpsys` line refs — unchecked field = `UNTESTED`-vocab per ch.07 §11, never blank): `LENS_FACING` vs physical mount (§9 + §31 mirror agree), `SENSOR_ORIENTATION` formula with numbers (§31), `SENSOR_INFO_PIXEL_ARRAY_SIZE` vs `SCALER_AVAILABLE_STREAM_CONFIGURATIONS` (max still = array active, not padded), `SCALER_CROPPING_TYPE` + `SCALER_AVAILABLE_MAX_DIGITAL_ZOOM` (v1 `CENTER_ONLY`, max 4× — zoom beyond is crop, honesty note in capability table §9), `CONTROL_AE_AVAILABLE_MODES` (OFF/ON always; ON_ALWAYS_FLASH iff flash sync §9 verified), `CONTROL_AF_AVAILABLE_MODES` (FIXED for fixed-focus SKUs — no fake `CONTINUOUS_PICTURE` advertised), `FLASH_INFO_AVAILABLE` (false where LED absent — advertising flash without LED fails CTS + lies to apps), `SYNC_MAX_LATENCY`/`REQUEST_PIPELINE_DEPTH` = contract numbers above (dump must equal doc or the MR explains), `INFO_SUPPORTED_HARDWARE_LEVEL` (`LIMITED` v1 — never `FULL`/`LEVEL_3` without reprocess + manual-sensor proof; over-claiming level breaks ProShot-class apps worse than honest LIMITED).

Failure table:

| Symptom | Check | Fix |
|---------|-------|-----|
| Green frames on one combo only | stride per resolution in pipeline doc vs `dumpsys` active stream | stride mismatch on that size — force `NV12` + `ALIGN(w,64)` isolate (§9) before ISP blame |
| `flush()` >500ms / ANR on app switch | adapter journal `flush` + ISP `streamOff` join trace | FW stall — watchdog path + FW version note + §23 vendor-drop row; never raise timeout silently |
| In-flight grows, results stall | `pending` in dumpsys + libcamera queue depth host log | HAL3 queue deeper than libcamera backlog — match depths (contract numbers) |
| Unlisted 4K combo crashes provider | `CAMERA-COMBO-UNSUPPORTED` metric absent + tombstone | missing graceful-reject — add combo-guard before `configureStreams` (P0) |
| Gralloc delta grows per open/close | `meminfo cameraserver` pre/post + `tests/camera-flush.sh` leak row | buffer free missed on abort path — fix `ERROR_REQUEST_ABORTED` free, re-run 50 cycles |

## 38. Sensors direct-report vs FIFO batching matrix (rate table, wakeup audit, register vs batch counters)

Doctrine (§10 multihal + §32 power restated as API contract): Android sensors reach apps two ways — FIFO batch (`batch()` + `flush()`, AP sleeps, driver drains) and Direct Report (`configureDirectChannel`, sensor writes shared-memory, no AP wake per sample). HALIDE v1: FIFO everywhere it exists (§32 win rule), Direct Report allowlisted per sensor (not per app — unlisted sensor+rate refuses with `SENSORS-DIRECT-UNSUPPORTED` + metric, never best-effort-now-jitter-later). Rationale logged (revisitable with data): direct-channel ashmem mappings widen the container/host shared-memory surface (threat-note per mapping, §5 modem-adjacent reasoning — each `DIRECT` sensor names its shm size + lifetime in the matrix; unthreat-noted mappings rejected in review).

Rate table per SKU (`sensors/<sku>/direct-vs-fifo.csv`, normative — columns `sensor,handle,fifo_depth,max_batch_s,direct_allowed,direct_rates_hz,fifo_rates_hz,wake_class,shm_kb,threat_note`):

| Sensor (handle) | FIFO depth | Max batch | Direct? | Direct rates | FIFO rates | Wake | Notes |
|---|---|---|---|---|---|---|---|
| accel (1) | 1024 ev | 6.0s meas | YES | 50/100/200Hz | 5/50/100/200Hz | non-wake | shm 64KB; game-need sensor — direct allowed |
| gyro (2) | 1024 ev | 6.0s meas | YES | 50/100/200Hz | 5/50/100Hz | non-wake | shm 64KB; fusion jitter hist §32 required |
| mag (3) | 256 ev | 10s meas | NO | — | 10/25Hz | non-wake | low-rate, FIFO wins; direct refused (no game need) |
| step-counter (5) | n/a on-change | n/a | NO | — | on-change + 1Hz read | wake | wake accounting §32; direct meaningless for events |
| ALS/prox (6/7) | n/a on-change | n/a | NO | — | on-change | wake(prox)/non-wake(ALS) | suspend-block audit §14 catches misuse |
| pressure/baro (8) | 64 ev | 30s meas | NO | — | 1/5Hz | non-wake | 1Hz stair-alias note §32 restated |
| rotation-vector (soft 11) | host-fused | host-batch 5Hz | NO | — | 5/15/50Hz | non-wake | fused in multihal — direct refused (no HW source) |

Rules: direct allowed only accel/gyro v1 (rows say YES — every other `configureDirectChannel` returns `BAD_VALUE` + metric; the metric is the demand signal for widening, same `FORMAT_FUTURE` counting as camera combos §37). Direct rates fixed sets (50/100/200 — 400Hz+ refused v1: jitter unproven on our IIO path, 200Hz histogram green required before any widen ADR). FIFO `maxDelayUs`/`fifoReservedEventCount` in `sensors_config.json` equal measured `max_batch_s`/depth (§32 — config-without-measurement amber rule applies here too; `measured:false` rows refuse direct even if YES).

Shell excerpts:

```bash
# 1. Handle map + FIFO truth (config vs kernel agree or MR explains)
lxc-attach -n android -- dumpsys sensorservice | grep -Ei 'handle|name|fifo|direct|maxDelay|wake' | head -50
cat vendor/halide/sdm845/sensors_config.json | python3 -m json.tool | grep -Ei 'handle|maxDelay|fifoReserved|direct' | head -40
# 2. Batch vs direct counters (the scoreboard — read before AND after every soak)
lxc-attach -n android -- dumpsys sensorservice | grep -Ei 'dropped-batch|direct|overflow|wakeup|active' | head -30
# 3. Direct-channel lifecycle probe (accel 100Hz 60s — the only blessed direct test v1)
lxc-attach -n android -- /vendor/bin/sensors_direct_test -s accel -r 100 -t 60 2>&1 | tail -12
# 4. Wakeup audit cross-check (screen-off 10 min with step-counter armed)
cat /sys/kernel/debug/wakeup_sources | grep -Ei 'sensor|sns|step|prox' | head -10
journalctl -u halide-sensors-multihal -S -15min | grep -Ei 'batch|direct|wakeup|overflow|TIME-UNTRUSTED' | tail -15
# 5. Jitter histogram (direct + FIFO both — fusion needs it)
lxc-attach -n android -- dumpsys sensorservice | grep -A12 -i 'jitter\|timestamp' | head -30
```

Expected outputs:

```
# dumpsys sensorservice (excerpt golden):
handle=1 accel fifoMax 1024 maxDelay 6000000us wake=0 direct=RATE_LEVELS(50,100,200Hz) active=1
handle=5 step-counter wake=1 direct=UNSUPPORTED active=1
dropped-batch=0 overflow=0 direct_sessions=1 wakeup_count(sensor)=3/10min (named: step x2, prox x1)
# sensors_direct_test:
direct accel 100Hz 60s: received 6000/6000 (0 lost), jitter p50 0.4ms p99 1.8ms — PASS (p99 ≤2ms §32)
# wakeup_sources:
step_detect 3 wakeups 120ms total (named — unnamed sensor wakes = misclassified non-wake, P1 §32)
```

Register-vs-batch counter discipline (the "sns注册 vs batch counters" audit — every sensor enable path counted): multihal exposes `register_count` (direct `register`/`configureDirectChannel` calls) and `batch_count` (`batch()`+`flush()` drain events) per handle in `dumpsys sensorservice` extended dump + host metrics `HALIDE-SENSORS-REGISTER`/`HALIDE-SENSORS-BATCH` (dashboard per device-week). Invariants asserted in `tests/hal-contract.sh`: `batch_count` grows during FIFO soaks (§32 100Hz-hour: `dropped-batch` 0 + `batch_count` ≈ duration/max_batch ±10%); `register_count(direct)` grows only for accel/gyro at allowlisted rates (any other handle with direct-register >0 = P1 + threat-note missing); wake sensors' `wakeup_count` attributed per handle (aggregate wakeups without per-handle attribution rejected — unattributed wakes hide §14 suspend-blockers). `sns_reg` (QMI SNS register, where modem-hub sensors route) vs `batch` cross-check on hub SKUs: `qrtr-lookup` SNS service + `sns_register_count` in adapter log must equal Android `register_count` for hub sensors ±0 (drift means dual-registration — host + container both polling the hub, power double-pays, P1).

Failure table:

| Symptom | Check | Fix |
|---------|-------|-----|
| Direct 200Hz jitter p99 >2ms | jitter hist + host IIO `sampling_frequency` + governor | AP DVFS too slow for direct drain — pin `schedutil` rate-limit per §25 or refuse 200Hz on that SKU (matrix row to NO with numbers, not hope) |
| `dropped-batch` grows at max-batch | watermark IRQ timing + `batch_timeout` (§32 overflow injection) | shorten `batch_timeout`, re-run shake-table 60s to 0 |
| Direct session on mag (refused row) succeeds | `direct_sessions` + threat_note absent | missing guard — add `BAD_VALUE` + metric (P1, surface widened without review) |
| Wakeups unattributed (`wakeup_sources` generic `sensorhub`) | multihal wake-class map vs kernel source name | name the handle (P1 — unnamed wakes block suspend triage §14) |
| `sns_register_count` ≠ Android register (hub SKUs) | adapter log + `qrtr-lookup` SNS + host IIO poll | dual-registration — kill host poller, single owner (multihal), re-run overnight drain §32 |

## 39. GNSS HAL week-rollover + leap-second test fixtures (mock NMEA, date-edge CI)

Doctrine (§33 policy restated as fixtures): rollover/leap-second handling is proven by checked-in fixtures replayed in CI, not by waiting for the sky. This section owns the fixture set, the replay harness, and the date-edge CI job — §33 owns the firewall semantics (untrusted-time flags, vote rules). Fixtures live in-repo (`tests/gnss-fixtures/`); simulator/IQ replay stays lab-manual (§33 battery) — fixtures catch parser/arithmetic bugs on every MR, the lab catches firmware bugs per drop.

Fixture inventory (each file: raw NMEA + QMI-PDS hex twin where the shim parses both + `META.json` with `utc_truth_iso`, `gps_week`, `leap_seconds`, `expect_time_valid`):

| Fixture | Edge covered | Key NMEA line | Expect |
|---|---|---|---|
| `rollover-1999-08-21.nmea` | 1st GPS rollover (1024-wk) | `$GPRMC,235959,A,...,210899,,,...` → next-day `220899` | date `1999-08-22`, `time_valid=true` (arithmetic, not +1024w) |
| `rollover-2019-04-06.nmea` | 2nd rollover (modern FW) | RMC date `060419` boundary ±7d set (7 files, -7d..+7d) | all 7 parse to contiguous dates, no 19.6y step |
| `rollover-future-2038.nmea` | next rollover rehearsal | synthetic week 2047→0 wrap | `TIME-UNTRUSTED` iff FW reports week-ambiguous flag, else correct 2038 date + journal line |
| `leap-2016-12-31.nmea` | leap second insertion (GPS-UTC 17→18) | RMC `235960` + `GPRMC` leap-pending flag twin | UTC `2017-01-01T00:00:00Z` exact, no 1s smear double-count |
| `leap-pending-week.nmea` | leap-week almanac advance notice | `GPGSV` + PDS `leapSecUnc` large | `time_valid=true` + `leap_pending` journal (vote still trusted, uncertainty honored §33) |
| `spoof-jump-time.nmea` | jump + time-step co-occur (§33 SUSPECT) | position +1.2km, RMC time +12s same epoch | `GNSS-SUSPECT` + `time_valid=false` (position delivered, clock not stepped) |
| `garbage-date.nmea` | FW zeroed/midnight bug | RMC date `000000` / year 1980 epoch | `TIME-UNTRUSTED`, no `HALIDE-GNSS-TIME-REJECT` storm (rate-limited 1/min) |

Mock-NMEA excerpt (checked-in shape — parsers tested against these bytes, not prose):

```
$GPRMC,235959.00,A,3723.2475,N,12158.3416,W,0.13,309.62,060419,,,A*73
$GPGGA,235959.00,3723.2475,N,12158.3416,W,1,07,1.2,9.0,M,-34.2,M,,*5B
$GPGSV,3,1,11,02,25,293,42,05,52,187,45,06,14,045,41,07,70,122,44*71
# META.json: {"utc_truth_iso":"2019-04-06T23:59:59Z","gps_week":2087,"leap_seconds":18,"expect_time_valid":true}
$GPRMC,000000.00,A,3723.2475,N,12158.3416,W,0.13,309.62,070419,,,A*74
# ... next-day continuity asserted: 060419→070419, never 060419→251199 (+1024w bug signature)
```

Replay harness (`tests/gnss-replay.sh`, runs VIRT nightly + HW weekly, JUnit + metrics):

```bash
# Replay every fixture through the real shim (not a python re-implementation)
for f in tests/gnss-fixtures/*.nmea; do
  halide-gnss-replay --nmea "$f" --meta "${f%.nmea}.META.json" --out /tmp/gnss-out.json
  python3 tests/gnss-assert.py /tmp/gnss-out.json "${f%.nmea}.META.json" || echo "FAIL $f"
done
# QMI-PDS twin path (hex fixtures through the same validity funnel §33)
for h in tests/gnss-fixtures/*.pdshex; do halide-gnss-replay --pdshex "$h" --out /tmp/gnss-pds.json; done
# Live cross-check (HW only, open-sky, §10 side-by-side — asserts lab battery ran)
gpspipe -r -n 30 | grep RMC | head -5; lxc-attach -n android -- dumpsys location | grep -Ei 'time_valid|gnss|week|leap' | head -10
```

Expected outputs:

```
# gnss-replay (per-fixture line, CI-parsed):
PASS rollover-2019-04-06(+0d): date 2019-04-07 time_valid=true leap=18 (Δ vs META 0s)
PASS leap-2016-12-31: utc 2017-01-01T00:00:00Z (no smear), time_valid=true
PASS garbage-date: TIME-UNTRUSTED (year<2000 rule §33), HALIDE-GNSS-TIME-REJECT +1 (rate-limited)
Suite: 14/14 PASS, 0 TIME-UNTRUSTED-unexpected, 0 GNSS-SUSPECT-unexpected
# dumpsys location (HW golden):
GnssLocation: lat 37.387 lon -121.972 time_valid=true sv=9 week=2341 leap=18 suspect=0
```

Date-edge CI job (`gnss-date-edge`, runs on every HAL MR + nightly `FAKETIME` sweep): libfaketime-style clock injection (`halide-gnss-replay --fake-clock 2038-11-20` etc. — 6 dates: each rollover ±1d + each leap ±1d + `2038-01-19` 32-bit boundary + `2040-01-01` upper-validity bound §33 `year>2040→untrusted`): asserts no crash, no `TIME-UNTRUSTED` storm (>10/min = bug — single rejection + steady state, not log-spam), container/host validity flags agree (§33 single-truth). `FAKETIME` sweep failures quarantine per ch.10 §11 (BUG + fixture, no re-green). Leap-second almanac update path tested (new `leap_seconds` value via SUPL-off almanac file drop → shim picks up within 1 fix + journal `LEAP-UPDATED 18→19` — stale-leap (off-by-1s UTC for months) caught here, not by user clock complaints).

Failure table:

| Symptom | Check | Fix |
|---------|-------|-----|
| `+0d` passes, `+1d` steps 19.6y | week-arithmetic width (10-bit mask on 13-bit week) | widen mask + add `rollover-future` fixture (regression locked by file, not comment) |
| Leap midnight double-second (00:00:00 twice) | smear vs step handling in shim + `leapSecUnc` | step-exact (no smear) per META; smear is NTP's job (ch.03 §36), not GNSS shim's |
| `TIME-UNTRUSTED` storm (>10/min) | rate-limiter + `garbage-date` fixture | clamp metric to 1/min + steady-state test (log-spam pages nobody, §33 alert drowned) |
| Host valid / container invalid (flag split) | `/run/halide/gnss.nmea` vs `dumpsys location` same epoch | single-truth break — validity flag must travel with the fix struct, not a second channel |
| CI green, lab simulator red | FW-version pin in test record (§33) | fixtures prove parser, simulator proves FW — record FW version; red simulator blocks vendor-drop promotion §23 |

## 40. Bluetooth audio (A2DP offload vs software) HAL pin + coexistence flags

Doctrine (§12 BT restated with audio teeth): two A2DP data paths — offload (container `audio` HAL hands encoded frames to BT controller via `IBluetoothAudio` HAL, host BlueZ uninvolved in media) and software (container decodes/mixes → PCM → host BlueZ → controller, v1 default per §12 bridge rule). v1 ships SOFTWARE (auditable, single EQ §30, host routing intact); OFFLOAD is bring-up-gated (SBC-only, one headset allowlist, same coexistence numbers required before promotion — offload without the numbers is §23-unqualified-vendor-drop-class). The pin is the version + path + flag triple committed per release — "BT audio improved" without the triple diffed is closed with link here.

HAL pin per SKU (`bt/<sku>/a2dp-pin.conf`, normative): `bluetooth_audio_hal` version (`android.hardware.bluetooth.audio@2.1` v1 — AIDL `IBluetoothAudioProvider` migration Phase-4 with skew-matrix evidence §24, not mid-train), `audio_hal_a2dp_node` (`software-pcm` v1 / `offload-sbc` gated), `controller_fw` (`cnss`/`wcn3990` version + `btPercival` patchram SHA), `host_bluez` version (host owns HCI §12 option-a — `bluetoothd --version` + kernel `btusb`/`btrtl` versions), `codec_allowlist` (v1: `SBC-mandatory, AAC-optional-per-headset, LDAC/aptX OFF` — each non-SBC codec names license + HCI-logged negotiation proof + §30 cert row with codec footnoted; unfootnoted "HD audio" claims rejected per ch.10 §8), `offload_gate` (`CLOSED` v1 — open requires §22 full HW soak + coexistence delta ≤30% §12 + 8h idle §3 row, all three, same NNAPI-entry discipline §20).

Coexistence flags (`bt/<sku>/coexist.conf` + datasheet antenna table §12): `wlan_bt_coex` (`WLAN-BT-PTA-3WIRE` on SDM845 — PTA priority `SCO>ACL-A2DP>WLAN-BESTEFFORT`,/at-risk `WLAN-SCAN-during-A2DP` flagged), `a2dp_mtu` (672 v1 SBC — 1016+ needs controller-buffer proof, no blind MTU raise), `tx_power_cap_dbm` (per-regulatory + thermal §25 modem-TX-backoff adjacency), `2g4_wifi_lock` (A2DP streaming test pins Wi-Fi to 5GHz first, then repeats on 2.4GHz — the delta IS the coexistence number §12: `iperf` without-A2DP vs with-A2DP-SBC-328kbps, both bands, CSV `bt/<sku>/coexist.csv`).

Shell excerpts:

```bash
# 1. BT service + audio-provider truth (container)
lxc-attach -n android -- dumpsys bluetooth_manager | sed -n '1,60p'
lxc-attach -n android -- lshal --debug | grep -i -E 'bluetooth|audio' | head -20
# 2. A2DP codec negotiation truth (HCI snoop — claims need packets)
lxc-attach -n android -- dumpsys bluetooth_manager | grep -Ei 'a2dp|codec|sbc|aac|ldac|offload|mtu|sample_rate' | head -30
hcidump -X -t 2>/dev/null | grep -Ei 'a2dp|sbc|aac|setconf|open|start' | head -20  # host side
# 3. Coexistence numbers (the §12 delta — both rows or the test didn't run)
iperf3 -c 192.168.1.1 -t 30 -J | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["end"]["sum_received"]["bits_per_second"]/1e6, "Mbps")'
# ... run with A2DP idle, then with A2DP SBC 328kbps streaming, both on 2.4GHz and 5GHz
journalctl -u bluetooth -S -35min | grep -Ei 'coex|pta|afh|retrans|drop' | tail -15
# 4. Offload-vs-software path assert (v1 must print software-pcm)
cat /run/halide/a2dp-path; lxc-attach -n android -- dumpsys media.audio_flinger | grep -Ei 'a2dp|bt_|offload' | head -10
# 5. HCI log capture for cert (codec-noted §30 BT row input)
hcidump -w bt/<sku>/hci-a2dp-sbc-`date +%F`.cfa; ls -la bt/<sku>/hci-*.cfa
```

Expected outputs:

```
# dumpsys bluetooth_manager (excerpt golden, software path):
A2DP state STREAMING, codec SBC (44.1kHz, bitpool 53, 328kbps), offload=false path=software-pcm
IBluetoothAudioProvider: not-bound (software path — binding present only on offload-gated builds)
# /run/halide/a2dp-path:
software-pcm sbc-328kbps bluez=5.66 controller=wcn3990-fw-0.3.2.1
# coexist.csv (REF-A golden shape):
band,codec,a2dp_state,iperf_mbps,drop_vs_idle
5G,SBC-328k,idle,210,-
5G,SBC-328k,streaming,198,5.7%
2.4G,SBC-328k,idle,68,-
2.4G,SBC-328k,streaming,47,30.9% (at-limit — antenna-tune before camera-polish §12)
```

Offload-gate test battery (runs only on offload-candidate builds — v1 runs it once to prove the gate holds CLOSED): SBC encode-in-controller loopback (1kHz tone 60s, THD+N §30 BT row with `offload-sbc` label — must match software within ±0.2% or the DSP resamples undeclared), suspend-with-A2DP (screen-off streaming 30 min — wakeup audit names `bt-a2dp`, suspend residency target relaxed per ch.05 §21 streaming row, but wakeups attributed §38 discipline), controller-crash injection (HCI reset mid-stream — `audio_flinger` A2DP thread must re-open ≤3s with `A2DP-REOPEN` journal, never wedge requiring toggle — wedge = P0 per §21 USB-wedge parity), codec-flap (headset reconnect 20× — `sample_rate` stable 44.1k, flapping 44.1↔48k = §30 cert bug, offload stays gated).

Failure table:

| Symptom | Check | Fix |
|---------|-------|-----|
| `offload=false` but no audio on headset | host BlueZ `pactl list sinks` + proxy `bluetooth` stream (§8) | PCM never reached BlueZ — socket perms/UID map (§7 audio-no-route row), not codec |
| Codec shows AAC, cert says SBC | HCI snoop `setconf` vs `dumpsys` | `dumpsys` cached — re-read post-`setconf`; cert row codec label from snoop, never UI |
| 2.4GHz drop >30% (§12 limit) | `coexist.csv` both bands + PTA wiring + antenna table | antenna-tune / PTA priority fix before any audio-polish MR (ordering rule §12) |
| `sample_rate` flaps 44.1↔48k | HCI log + §30 resampler row | double-resample (§36 FAST-row companion) — pin 48k-fixed boundary, re-cert |
| Offload build wedges on HCI reset | `A2DP-REOPEN` journal absent + thread state | missing reopen path — gate stays CLOSED (P0, USB-wedge parity §21) |

## 41. Light/vibrator/power-stats HAL calibration sheets (per-SKU lux curves, haptic waveforms)

Doctrine (§11 small-HALs restated as metrology): brightness, haptics, and energy numbers ship with calibration sheets or they don't ship. Every lux-to-nit mapping, every haptic waveform, every joule in `PowerStats` traces to a rig + a CSV + a cal ID (ch.10 §8 footnotes — unfootnoted numbers rejected like unprovenanced DT lines ch.03 §13). Sheets live per SKU and version with the build (`lights/<sku>/lux-curve.csv`, `vibrator/<sku>/waveforms.csv`, `power/<sku>/energy-model.csv`); the HAL reads the sheet at boot (no hardcoded curves in `.cpp` — hardcoded lux tables are untestable blobs, review-rejected like hardcoded DT).

Lux curve sheet (`lights/<sku>/lux-curve.csv`, normative — backlight truth §11 single-truth + §31 low-light AE adjacency): columns `als_lux,backlight_01,nits_measured,panel_pwm_hz,ae_exposure_ms_note`. REF-A shape (re-measure per panel lot — panel lots drift, copied curves throttle wrong per §25 never-copy rule):

| ALS lux | Backlight 0–255 | Nits | PWM | AE note |
|---|---|---|---|---|
| 0 (dark) | 8 | 4 | 1200 | AE 33ms, preview-only combo §37 |
| 10 (hall) | 32 | 28 | 1200 | AE 16ms |
| 100 (office) | 96 | 120 | 2400 | AE 8ms |
| 1000 (shade) | 180 | 320 | 2400 | AE 4ms |
| 10000 (sun) | 255 | 480 | 2400 | HBM iff panel supports (datasheet flag, never assumed) |

Procedure: dark-room + calibrated lux meter (cal ID in sheet header) + CS200-class colorimeter at panel center; slider sweep host 0→100% + Android `cmd lights` readback agreement (§21 lights drill — divergence = cache bug, P1); flicker check (PWM <1000Hz at low-nits fails — visible strobing on camera preview §37 low-light row, bump PWM or document `FLICKER-KNOWN` with lot range); ALS hysteresis (±15% — flapping backlight at threshold = hysteresis missing, 5-min office-doorway test with ALS log); suspend-with-LED rule (§21 drill restated: LED active must not block suspend — wakeup audit row `lights-led` 0 wakes/8h).

Haptic waveform sheet (`vibrator/<sku>/waveforms.csv` — columns `effect,duration_ms,freq_hz,amplitude_01,current_ma,rise_ms,fall_ms,audible_dbA_10cm`): v1 catalog `click(15ms/170Hz/1.0) tick(8ms/200Hz/0.6) double-click(2×15ms+40ms-gap) call-pattern(1s-on/2s-off per §21 5-min loop) notification-sweep(80ms ramp 0.3→1.0)`. Each row measured (accelerometer rig or audio-envelope method per §21 — method named in sheet; current via `idaemon` meter + cal ID; audible <40dBA@10cm for click (buzzing = resonant-frequency miss — re-tune `freq_hz` to motor resonance ±5Hz, datasheet + sweep-probe, not volume-down-hiding)). Duration accuracy ±10ms on 100ms pulse (§21 — envelope plot archived per release-train); motor-age divergence (dogfood quarterly re-measure — worn-motor amplitude drop >20% vs baseline flags `MOTOR-WORN` RMA-track ch.02 §18, not averaged into the sheet).

Power-stats sheet (`power/<sku>/energy-model.csv` — `IPowerStats` AIDL energy-meter contract): columns `rail,meter_source,scale_mw_per_ma,offset_mw,valid_range_ma,cal_id`. Rails v1: `cpu-little/cpu-big/gpu/modem-tx/wifi-rx+tx/display/haptics/sensor-hub` (each rail names `meter_source`: `INA231`/`fuel-gauge-coulomb`/`model-estimate` — `model-estimate` rows carry `measured:false` amber + widening condition (named meter part + driver), same honesty as `measured:false` batch rows §38). `dumpsys powerstats` vs meter agreement (30-min mixed load: reported vs `idaemon` integral ≤8% per rail, ≤5% total — wider = model bug, fixed in sheet with version bump, never UI fudge per §34 battery-model parity). Modem-TX rail cross-checks RIL ladder (§4: TX current during `iperf`-over-LTE vs idle — TX rail must move, static rail during upload = meter disconnected, P1). Haptics rail feeds §21 current-draw note; sensor-hub rail feeds §32 per-sensor attribution (three sheets agree or the MR names which meter lied).

Shell excerpts:

```bash
# 1. Lights truth both sides (single-truth §11 assert)
lxc-attach -n android -- dumpsys lights | grep -Ei 'backlight|brightness|led|mode' | head -20
cat /sys/class/backlight/*/brightness; cat /sys/class/backlight/*/max_brightness
lxc-attach -n android -- cmd lights set 5 128 2>/dev/null; sleep 1; cat /sys/class/backlight/*/brightness
# 2. Vibrator catalog + amplitude sweep (§21 drill commands, sheet rows)
lxc-attach -n android -- dumpsys vibrator | grep -Ei 'amplitude|effect|duration|always-on' | head -20
for a in 26 128 255; do lxc-attach -n android -- cmd vibrator vibrate 100 $a; sleep 1; done  # 10/50/100%
# 3. PowerStats vs meter (energy contract — the numbers that feed ch.05 §21 budget)
lxc-attach -n android -- dumpsys powerstats | grep -Ei 'rail|energy|uws|model|version' | head -40
head -20 power/REF-A/energy-model.csv; grep -c measured:false power/REF-A/energy-model.csv
# 4. Sheet-version assert (HAL read the sheet — not hardcoded)
journalctl -u halide-lights-hal -S -10min | grep -Ei 'lux-curve|version|lot' | tail -5
journalctl -u halide-vibrator-hal -S -10min | grep -Ei 'waveform|version|resonance' | tail -5
```

Expected outputs:

```
# dumpsys lights + sysfs agree (single truth):
lights: backlight=128/255 mode=USER_SETTING brightness=0.50
/sys/class/backlight/panel0-backlight/brightness: 128 (mirror ≤1 step lag, else cache bug P1)
# dumpsys vibrator:
IVibrator: amplitudeControl SUPPORTED, catalog 5 effects (click/tick/double-click/call-pattern/sweep) model_v3
# dumpsys powerstats:
PowerStats model_v7 rails 8: cpu-little 12mWh cpu-big 31mWh modem-tx 44mWh display 88mWh (30min mix)
  agreement vs idaemon: total 3.8% (≤5% PASS), worst-rail wifi 6.1% (≤8% PASS)
# hal journals:
lights-hal: lux-curve v12 lot=BOE-2024-11 resonance=n/a loaded 9 points
vibrator-hal: waveforms v3 resonance=172Hz loaded 5 effects
```

Failure table:

| Symptom | Check | Fix |
|---------|-------|-----|
| Slider vs sysfs diverge >1 step | `cmd lights` + sysfs + bridge log | cache split (someone cached) — single-truth fix, re-run sweep §21 |
| Click audible buzz >40dBA | resonance vs `freq_hz` + sweep-probe | re-tune to motor resonance ±5Hz (sheet bump, not volume-hide) |
| `powerstats` total error >5% | per-rail errors + meter cal IDs | worst rail first (usually `model-estimate` wifi/modem) — meter or model, named in MR |
| Sheet version in journal ≠ CSV | sheet load path + `halide.version` guard §15 | HAL booted stale sheet (mixed-version §15 refusal should have fired — ordering bug) |
| Lot-change brightness shift >10% | panel lot ID vs curve lot tag | re-measure that lot (never-copy rule §25) + lot-tagged sheet version |

## Verification

- [ ] `sys.boot_completed=1` headless on REF-A; `service list` shows radio/audio/camera/sensors.
- [ ] 20 stills + 60s 1080p30 + 10-min call audio loop pass (allow documented quality delta).
- [ ] No new `avc: denied` vs baseline recorded in `logs/<sku>-selinux-baseline.txt`.
- [ ] Audio 5-call tuning log + `tinymix` baseline archived per SKU.
- [ ] Camera per-sensor capability table + blind quality vote archived.
- [ ] GNSS cold/warm TTFF measured open-sky, logged with AGPS on/off.
- [ ] Wi-Fi 8h idle + roam + BT HFP/A2DP loop pass with coexistence numbers.
- [ ] Every §3 HAL has a RUNBOOK.md with owner + drill date ≤90 days; `tests/HAL-COVERAGE.md` has no empty cells.
- [ ] Last vendor drop carries inventory + staged-boot probes + power delta + dual sign (BSP + Security).
- [ ] Audio effects cert `effects-cert.csv` archived incl. BassBoost-ON negative control FAIL (§30); blessed-effects.conf enforced.
- [ ] EXIF orientation battery green per sensor: plumb-line ±1°, 4-rotation burst, `exiftool` tag histogram (§31).
- [ ] Sensor batch power table signed: FIFO win ≥30% or `FIFO-NOT-WORTH-IT` with numbers; overnight drain ≤3%/8h (§32).
- [ ] GNSS rollover battery green on current modem FW: simulator ±7d + live-sky date Δ≤1d + AGPS-off cold start (§33).
- [ ] Battery-curve `model_vN` + 0–100–0 loop error plot archived; learned-FCC persists across slot switch (§34).
- [ ] Gadget matrix `gadget-matrix.csv` all 9 states green; 20-rapid-switch wedge-counter 0; locked-device USB consent enforced (§35).

Next: `05-debian-systemd-dual-init.md`.
