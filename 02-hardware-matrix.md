# 02 — Hardware Matrix & Reference Devices
**Budget: 50,000 chars · Phase: 0 · Owner: Hardware/BSP**

## 1. Strategy: 2 reference devices + 1 emulator

Do not attempt "all phones". Bless exactly two physical references for v1 plus QEMU/Cuttlefish for CI:

- **REF-A (primary, Qualcomm):** Snapdragon 845 device with mainline support (e.g., OnePlus 6 / SHIFT6mq class). Why: best mainline DRM/Freedreno + modem separation docs, abundant UART/fastboot knowledge, replaceable battery options on some SKUs.
- **REF-B (secondary, MediaTek or Pixel/Tensor):** one Dimensity-class or Pixel 6 (Tensor/Exynos-derived) for modem-diversity. Expect more blob pain; timebox to 6 weeks behind REF-A.
- **VIRT (CI):** `aarch64` QEMU + Cuttlefish for HAL/API smoke without radio.

Graduation rule: a device becomes "supported" only after Phase-3 DoD on that exact SKU (storage/RAM/modem variant pinned). Variants are separate rows, not footnotes.

## 2. Reference device record template (copy per SKU)

```
SKU: <vendor model + storage/RAM + region>
SoC: <e.g., SDM845 sda845>
Modem: <e.g., X20 integrated, QMI over QRTR>
Display: <panel id, resolution, backlight driver, touch controller>
Audio: <WCD934x, speaker amp, mic topology>
Camera: <sensor list, ISP path, flash driver>
GNSS/WiFi/BT: <chip, antenna sharing notes>
Battery/fuel-gauge: <PMIC, gauge IC>
Boot: <PBL→XBL→ABL/fastboot availability, EDL recovery, AVB state>
Blobs required: <list with version + extraction source>
Mainline status: <kernel version first boot, missing drivers>
Owner: <name>  Status: <Phase 0/1/2/3>
```

## 3. SoC bring-up inventory (per SoC, fill for REF-A first)

**Clock/power:** rpmpd domains, interconnect votes, `power-domains` in DT. Verify: `cat /sys/kernel/debug/pm_genpd/pm_genpd_summary` shows expected domains; suspend prints `PM: suspend entry (deep)`.

**Serial/UART:** 115200 8n1 pads, cable pinout photo in repo (`hw/<sku>/uart.jpg`). Log full boot to `logs/<sku>-boot-<date>.txt` from day one.

**Storage:** UFS version, `ufshcd` quirks, LUN layout (`/dev/disk/by-partlabel`). Record stock partition table before flashing (mandatory backup step).

**Display:** panel driver (or simple-panel fallback), DSI timings, backlight PWM, touch I2C/SPI + firmware. Test: `modetest -M msm` shows connector + mode; `evtest` shows multitouch slots.

**GPU:** Freedreno/Turnip (Adreno) or Mali (Panfrost/Valhall — expect pain; prefer Adreno for REF-A). Test: `glmark2-es2-drm` runs ≥60 frames without `pageflip timeout`.

**Modem:** QRTR + QMI (`qrtr-ns`, `qmi_wwan`/`rmnet`), SIM detect GPIO, antenna. Test Phase 1: `qmicli -d /dev/cdc-wdm0 --dms-get-ids` returns IMEI (redact in logs).

**Wi-Fi/BT:** ath10k / WCN39xx firmware paths, MAC provisioning (persist partition), BT UART+HCI. Test: `iw wlan0 scan` + `bluetoothctl → show`.

**Audio:** ASoC machine driver, jack detect, DMIC mapping. Test: `aplay -l`, speaker+mic loopback at known gain.

**Camera:** sensor + CSI + ISP (CAMSS). Mainline stills via libcamera first; Android HAL later. Test: `cam -c1 -C5` capturesor `qcam` preview.

**Sensors/GNSS:** accel/gyro/mag/pressure/light/proximity over IIO; GNSS via modem QMI PDS. Test: `iio_info`, `gpspipe -r` NMEA.

**USB/OTG:** dwc3 role-switch, DP alt-mode (document as v1 non-gate).

## 4. Blob policy (binding)

1. Inventory every non-upstream firmware with: filename, version, SHA256, license, extraction command, redistribution flag.
2. Store in `vendor/<sku>/` with `BLOBS.md`. Never commit redistributable-forbidden blobs to public git; provide extractor script from stock OTA.
3. Pin versions per release; blob bumps are release notes entries with regression test IDs.
4. Prefer upstream linux-firmware; fallback to stock extraction with `extract-files.sh` (Lineage-style) adapted per SKU.

Example extraction skeleton:

```bash
STOCK_OTA=~/hybrid/blobs/stock-<sku>.zip
mkdir -p vendor/<sku> && cd vendor/<sku>
unzip -o "$STOCK_OTA" 'firmware/*' 'radio/*'
sha256sum $(find . -type f) | tee BLOB-SHA256.txt
cat > BLOBS.md <<'EOF'
# Blob inventory — <sku> — <date>
| file | sha256 (prefix) | source | redist? |
|------|-----------------|--------|---------|
EOF
```

## 5. Device-tree & bootloader specifics

- Base DT from mainline `arch/arm64/boot/dts/qcom/sdm845-*.dts`; overlays in `hw/<sku>/dt/` for panel/touch/battery deltas. No out-of-tree board files.
- ABL/fastboot required: `fastboot getvar all`, `fastboot boot`, `fastboot flash`. If ABL locked, document EDL/unlock consequence and do not bless device.
- AVB: preserve `vbmeta` flow even in dev builds (`--flags 0` dev vs `2` release). Record rollback indexes per slot.
- Backup ritual (mandatory, in runbook): `adb pull` persist/EFS/modemst1+2 + full `gpt` dump before first flash. Store offline + checksum.

## 6. Power & thermal envelope (per SKU)

Record: battery mAh, charge IC + max current, thermal zones (`/sys/class/thermal`), throttling trip points, modem PA thermal coupling notes. Phase-3 power tests in ch.10 reference these numbers; do not claim parity without same-ambient measurements.

## 7. Procurement & lab minimum

- 2× REF-A (one daily-driver dogfood, one sacrificial), 2× REF-B, UART cables, USB-PD meter, programmable PSU optional, thermal camera shared, RF-shield bag for modem isolation tests.
- Label every unit (`HALIDE-A1`…) and log flashes in `hw/flash-log.csv`.

## 8. Worked example: REF-A record (SDM845 class — adapt, don't copy blindly)

```
SKU: Example SDM845 dev unit 6/128GB EU ( avalanche-black )
SoC: Snapdragon 845 (SDM845), 4×Kryo385-Gold + 4×Kryo385-Silver, Adreno 630
Modem: X20 integrated, QMI over QRTR (qrtr-ns + qmi_wwan + rmnet DATA)
Display: 6.28" 1080×2280 AMOLED + DSI panel driver variant A, backlight
  PMI8998 WLED, touch FT8719-class I2C (firmware touch_fw.bin v12)
Audio: WCD934x + WSA881x speaker amp, 3-mic topology (top/bottom/back),
  jack detect via WCD MBHC
Camera: rear IMX519-class 16MP + S5K3P9-class 20MP aux, front IMX371-class;
  ISP via CAMSS (mainline) + documented quality delta vs stock (ch.04 §9)
GNSS/WiFi/BT: WCN3990 (ath10k WLAN + UART HCI BT), shared 2.4/5GHz + BT
  antenna (coexistence measured, ch.04 §12)
Battery: 3300mAh + PMI8998 charger (max 5V/4A stock, capped 5V/3A HALIDE v1
  pending thermal review) + MAX17040-class gauge
Boot: PBL→XBL→ABL, `fastboot boot/flash` OK, EDL 9008 via button combo
  (hw/<sku>/edl.md photo), AVB vbmeta preserved, unlock wipes (documented)
Blobs: adsp/cdsp/mpss mbn + wcn3990 firmware + touch_fw v12 + panel cfg
  (extract-files.sh from stock OTA build <fingerprint>, SHAs in BLOB-SHA256.txt)
Mainline status: 6.6 LTS boots UART+DRM+UFS; gaps tracked: CAMSS aux sensor,
  WCN3990 BT SCO quirks (bugs linked)
Owner: BSP lead   Status: Phase 1 (UART+DRM green, modem-host in progress)
```

Rule: no field stays `<TBD>` past its phase (panel/touch by Phase 1, modem by Phase 2, camera-aux by Phase 3b) — stale TBDs fail the gate review.

## 9. Peripheral inventory tables (fill per SKU, commit the dumps)

Display/touch: panel id (`dmesg | grep -i panel`), DSI mode (`modetest`), backlight range + measured nits at 5 points (lux meter), touch controller + firmware version + slots (`evtest` 10-finger). Audio: `aplay -l`/`arecord -l` card list, `tinymix contents` (baseline committed), mic/speaker mapping photo + jack-insert event log. Camera: `cam -l` sensor list + per-sensor `camera/<sku>/<sensor>.md` (ch.04 §9). Sensors: `iio_info` dump + per-sensor sysfs read proof (tilt changes accel raw). Radio: `qrtr-lookup` + `qmicli --dms-get-ids` (redacted) + `mmcli -m` RAT/bands + SIM SKU tested. Power: `pm_genpd_summary` + thermal zones list + charge-IC max + gauge full-charge-capacity vs design. Storage: `lsblk` + UFS gear (`ufshcd stats`) + eMMC/SD presence. Every dump lives in `hw/<sku>/dumps/<date>/` with the exact commands in `hw/<sku>/DUMP-PROCEDURE.md` (re-runnable by anyone holding the unit).

## 10. VIRT (emulator) specification

QEMU `aarch64` `virt` machine + Cuttlefish (HAL/API smoke, no radio): pinned QEMU version in manifest, `virt` DT (no panel — `virtio-gpu` + Wayland), `virtio-net` standing in for modem (netd-bridge contract tests run here, real QMI only on hardware). Nightly boots VIRT with the same `host.img`+container shape (smaller super) and runs: boot-timing, permission-sync ×20, VPN-leak, drawer screenshot diff. VIRT-green is necessary but never sufficient for hardware gates (the plan states this twice so nobody confuses them).

## 11. Flash log & UART discipline (the lab notebook that saves ports)

`hw/flash-log.csv` columns (append-only, never rewritten): `timestamp,unit,operator,from_ver,to_ver,method(fastboot/edl/recovery),result,boot_completed_s,notes_link`. Every flash of every unit logged — including failed ones (failed flashes are data: EDL-loop entries reference ch.03 §10 causes). Monthly `flash-log` review: brick-rate per method, slowest-operator retraining (kindly), cable-retirement decisions (cables cause 30% of "flaky device" reports — log the cable serial too, column 9).

UART discipline: every unit has a dedicated adapter labeled with the unit (`A1-UART` — adapters migrate between units and corrupt logs; labeled adapters stay). Log capture always with `tio --log` + timestamp (`--timestamp`); raw logs kept 90 days, boot-failure excerpts kept forever linked from the bug. Baud-rate gotcha (porting-week1 lesson) printed on a sticker on each rig: "115200 8n1 — if garbage, check baud FIRST". Stock-boot golden log per SKU captured before first HALIDE flash (appendix-03A §4 step assumes it exists — the gate review checks).

## 12. SKU variant policy (variants are SKUs — the graduation rule with teeth)

Storage/RAM/region/modem-firmware variants each get a record row (ch.02 §2 template), not a footnote: 6GB vs 8GB RAM = separate memory-map verification (appendix-03A §2 two-variant rule); regional modem-firmware = separate carrier-matrix rows (ch.07 §11 profile per MCC-MNC, not per "phone"); panel-second-source (variant B glass) = separate `panel.json` (ch.06 §11 mismatch-halt exists because of exactly this). Variant test discount (the only discount allowed): shared-SoC variants skip UART-bringup repetition (same pads documented) but repeat panel+touch 5-step (appendix-03A §4 — glass differs silently), modem ladder §2 steps 1–3 (firmware differs silently), and power calibration (ch.10 §8 — different DRAM/Flash idle). Discount abuse (claiming variant coverage without running the three repeats) is a gate-review fail with the variant demoted to UNTESTED-bold (same rendering as carrier UNTESTED, ch.07 §11 lint extended to variant tables).

## 13. Lab upkeep & calibration schedule (the lab is infrastructure — maintain it like CI)

Meters/PSU: annual cal against reference (offset recorded in power/<sku>/calibration.md, ch.10 §8 — expired cal blocks power-gate sign, not waived). Thermal camera: blackbody spot-check semi-annually (±2°C bar for skin-temp claims). Cables: quarterly continuity + CC-line check (ch.02 §11 flash-log cable serials identify the killers — failed cables labeled DESTROY, not drawer-returned). UART adapters: driver-version pinned per host OS upgrade (adapter-driver updates corrupt timestamps — pin + test post-upgrade). Reference stock phone: kept on stock OTA schedule (oracle must match current stock — stale oracle comparisons flagged by build-date check in perf sheets). RF-shield bag: integrity check (phone inside + call it — rings = bag retired). Spare-parts shelf: 1 spare panel + 1 spare battery per REF (2-week procurement gaps don't pause dogfood — shelf restocked on use, owner Lab-kept in RACI ch.11 §2 QA row).

## 14. Deprecation & removal (devices retire — gracefully, not by rot)

Support levels (per SKU row, ch.02 §2 record extended): BLESSED (full gates + dogfood), COMMUNITY (boots + radio + volunteer maintainer named — unnamed-maintainer builds demote to ARCHIVED), ARCHIVED (last-known-good image + export guidance, no updates — eol runbook applies per-device). Demotion triggers: maintainer departure without successor (90-day search, then demote — announced, not discovered), modem-fw unobtainability (can't re-bless per ch.07 §18 → can't stay BLESSED), gate failure 2 consecutive releases (honest demotion beats pretending). Demotion notice: 90 days + final-signed image + data-export drill on that SKU (eol §2 procedure per-device) + migration suggestion (which BLESSED SKU to buy — concrete help, not "good luck"). Removal from tree (code deletion, not just images): 6 months post-demotion + Arch sign + porting-guide note (someone may re-bless later — removal preserves the bring-up logs that make re-blessing cheap).

## 15. Second-source part qualification (panels, batteries, touch — the silent killers)

Trigger: any BOM change (panel second-source glass, alternate battery vendor, touch FW rev, WCN firmware bundle) opens a `hw/2ND-SOURCE/<part>-<date>/` qualification packet — no packet, no build consumption. Packet contents: (1) vendor datasheet + spec delta vs primary (one-page diff table, not 200-page PDF dump), (2) 5-unit sample incoming-QC results (§16 procedure), (3) panel/touch 5-step (appendix-03A §4) on 2 of the 5 samples, (4) power calibration delta (ch.10 §8 — panel backlight curve + touch idle current; >10% delta requires Arch review), (5) modem coexistence re-measure (§12 discount trio — non-skippable), (6) 72h soak (suspend cycles + display on/off + charge cycle) with zero P0.

Acceptance bars per part class. Panels: brightness curve within ±15% of `panel.json` at 5 points or new `panel.json` variant file (never overwrite variant A with variant B numbers — §12 variant rule); touch residual <8px with new matrix file; DSI error count 0 over soak (`dmesg | grep -ci dsi.*err`). Batteries: capacity ≥95% design (0.2C discharge, calibrated meter §13), charge-IC temp within envelope ch.02 §6, gauge `full_charge_capacity` within 5% across the 5 samples (spread >5% = lot rejected — gauge spread predicts field "my battery lies" bugs). Touch FW: version pinned in BLOBS.md + 100-swipe false-reject test (<3 drops, ch.06 §7 heuristic re-validated — FW revs change palm curves silently).

Graduation: packet reviewed by BSP + QA; approved parts gain a `panel.json`/BLOBS row + variant record row (§2 template) + compat note in release notes ("variant B glass supported from vX.Y"). Rejected lots: labeled REJECT + photo + reason in packet (prevents re-ordering the same bad lot in 6 months). Emergency substitution (supply crunch): 2-unit mini-packet + 48h dogfood + time-boxed approval (30-day expiry, full 5-unit packet due before expiry or variant demotes to UNTESTED per §12).

## 16. Incoming-QC inspection procedure (every unit, every part — 20 minutes that saves ports)

Scope: all REF phones (new/used), spare panels/batteries, UART adapters, cables, PSU leads. Station: bench with calibrated meter (§13), lux meter, USB-PD tester, magnifier, ESD mat. Procedure per phone (checklist `hw/IQC-PHONE.md`, signed + filed per unit serial): (1) visual (cracks, swollen battery, corroded USB-C pins — photo any defect), (2) stock boot (record stock build fingerprint + modem FW version — oracle baseline §13), (3) `fastboot getvar all` archived (bootloader drift detection ch.03 §18), (4) GPT + persist/EFS backup BEFORE any HALIDE flash (§5 ritual — IQC verifies backup restorability by checksum, not just file presence), (5) sensor spot-check (`iio_info` non-empty + accel changes on tilt + touch 10-finger `evtest`), (6) radio spot-check (`qmicli --dms-get-ids` redacted + `iw wlan0 scan` ≥3 SSIDs + BT `show`), (7) battery (design vs `full_charge_capacity`, charge to 100% + 10-min idle drain sanity), (8) panel (5-point nits + dead-pixel solid-color screens + backlight flicker 240fps phone-camera check per ch.03 §13).

Per-spare-part: panels (visual + ID read + 5-point nits after install on sacrificial unit — panel QC without install is wishful thinking), batteries (voltage + date code + capacity sample per lot: 1 per 10 tested 0.2C), cables (continuity + CC-line + data-rate smoke `fastboot flash --dry-run`-class transfer; failures → DESTROY label per §13, never drawer-returned).

Disposition: PASS (enter traveler system §17), CONDITIONAL (usable with named limitation + BUG link, e.g., "weak vibrator — haptics tests exempt"), FAIL (quarantine shelf + photo + RMA loopback §18 if vendor-covered). IQC log `hw/iqc-log.csv` (append-only like flash-log §11): `date,unit/part,inspector,result,backup_sha,stock_fw,notes_link`. Monthly review with flash-log (§11): correlates brick/flake rates to IQC gaps (skipped-IQC units that later brick are training material, kindly presented).

## 17. Unit labeling/traveler system (every device has a passport)

Physical labels: unit ID (`HALIDE-A1`… per §7) + QR (URL to traveler file) + UART adapter pairing (`A1-UART`) + cable serial on the cable (not the bench — §11 lesson). Traveler file `hw/travelers/<unit>.md` (source of truth, updated at every touch): header (§2 record SKU + serial/IMEI-redacted + purchase date/vendor + warranty terms), IQC result (§16 link), flash history (auto-extract from `flash-log.csv` §11 — traveler shows last 10 + link to full log), hardware mods (battery/panel swaps with 2ND-SOURCE packet links §15), damage log (drops, USB-C wear, battery swelling — with photos), role (dogfood/sacrificial/bench/oracle-stock — role changes logged with reason; sacrificial units never silently become dogfood), current assignment (holder + date — "in someone's drawer" without a name is how units vanish).

Role rules: dogfood units (daily-driver §7) flash release + staged OTA only (no EDL experiments — sacrificial exists for that); sacrificial units take all risks (bisect §21, EDL drills, resin tests ch.03 §19) and are expected to scar (damage log is honors, not shame); oracle-stock unit (§13) never flashes HALIDE (reference stays reference — flashing the oracle is a process P1). Traveler gate: any lab procedure (flash, panel swap, power measure) starts by reading the traveler (5s) and ends by updating it (30s) — procedures with stale travelers (last update >30 days on an active unit) are bounced in review.

Quarterly traveler audit: Lab-kept (RACI ch.11 §2 QA row) verifies every active unit's traveler vs physical label + flash-log tail; mismatches filed as lab bugs (not blame — the audit exists because drift is normal). Lost-unit protocol: last-holder + last-traveler-entry + last-flash-log row triangulate; report within 48h (enterprise P3 audit trail depends on device custody honesty).

## 18. RMA loopback process (field failures teach — if captured, not anecdoted)

Entry criteria: any dogfood/lab unit with suspected hardware fault (no-charge, no-boot, modem-dead, panel lines, swelling, USB-C intermittent) opens `hw/rma/<unit>-<date>/` case file (never debug-by-chat without a case — chat scrollback is not a failure record). Case file: symptom + first-seen build + traveler link (§17) + flash-log excerpt (§11) + UART/pstore logs + photos + IQC baseline (§16 — "was it ever good?" answered from data) + 2ND-SOURCE packet if swapped part involved (§15).

Triage ladder (48h): (1) software-excluded? (reflash known-good release + stock-oracle cross-check on sacrificial-adjacent unit — "reflash fixed it" without oracle check is INCONCLUSIVE, not CLOSED), (2) accessory-excluded? (swap cable/charger/UART adapter with known-good serials — 30% cable rule §11 applies to RMA too), (3) part-isolated? (panel/battery/USB-board swap with traveler update — isolation by swapping two unknowns simultaneously is forbidden), (4) vendor-RMA vs lab-scrap decision (warranty terms from traveler header + vendor RMA portal ticket ID recorded; out-of-warranty + uneconomical = teardown-for-spares with photo inventory, never trash-with-battery — battery disposal per local e-waste rule documented in case).

Loopback (the point of the process): every CLOSED case gains a `LESSON:` paragraph linked to a preventive change (IQC step added §16, traveler rule §17, 2ND-SOURCE bar raised §15, flash-map guard ch.03 §18, or `NO-CHANGE:` with reason — "freak drop, no systemic lesson" is acceptable when stated, not defaulted). Monthly RMA review with flash-log + IQC (§11+§16): top-3 failure modes trended (rate per 100 device-weeks); repeat mode twice in a quarter → P1 engineering bug (not "bad luck batch" — batches are tracked by lot in IQC log, so luck claims are checkable). Vendor scorecard semi-annual: per-vendor RMA rate + turnaround + packet quality (§15) — informs next procurement (§7 quantities adjusted by data, not loyalty).

## 19. Storage/RAM SKU fork procedure (memory variants are hardware variants)

Trigger: same SoC/region, different DRAM (6GB vs 8GB) or UFS size (64GB vs 128GB) enters the lab — fork the traveler (§17) + variant record row (§12) on day one, never "test later on the other size". Memory-map verification (per appendix-03A §2 two-variant rule): capture `cat /proc/meminfo` + `dmesg | grep -i -e memory -e cma -e ramoops` on both variants (CMA carveouts + ramoops addresses shift with DRAM size — a ramoops address valid on 8GB can overlap DRAM-hole on 6GB; the §9 pstore path is re-validated per variant with a forced `sysrq-c` on eng + ramoops-present check). UFS size fork: `lsblk` + `flashmap.json` slot math (ch.03 §18 — super-partition + userdata split recomputed; flashing the 128GB map onto 64GB is the classic cross-SKU brick the size-guard wrapper exists to refuse — test the refusal explicitly per variant).

OOM/lmkd behavior fork: run the same memory-pressure workload (`stress-ng --vm 2 --vm-bytes 80%` + Android 10-app cold-start sequence) on both variants; record lmkd kills + host OOM score deltas (6GB kills earlier — kill-order table per variant in `hw/<variant>/oom-behavior.md`; container `lmkd` props per-variant, never shared). Power fork: idle + suspend currents re-measured per variant (different DRAM density = different self-refresh current — ch.10 §8 calibration repeated, not copied). Promotion: both variants pass the §12 discount trio independently (panel/touch 5-step + modem ladder steps 1–3 + power calibration); shared-SoC UART-bringup skip is the only allowed discount (§12 text enforced literally — any broader skip fails gate review with variant demoted to UNTESTED-bold).

## 20. Antenna/RF path documentation standard (radio honesty starts at the antenna)

Per-SKU RF record (`hw/<sku>/rf-path.md`, photo-illustrated): antenna inventory (count, bands each, shared vs dedicated Wi-Fi/BT/GNSS/cellular paths from teardown + datasheet), connector/pogo inventory (U.FL/IPEX presence, test-port locations with microscope photos — untested test-ports don't exist for bring-up purposes), coex filters (SAW/BAW part numbers where visible, sharing matrix Wi-Fi-2.4/BT/GNSS-cellular with measured isolation notes), SIM/SD tray mechanics (dual-SIM variant = variant row §12 + per-slot modem ladder; tray-wear log in traveler §17 after 50 swaps — worn trays cause "SIM not detected" ghosts filed as modem bugs without this log).

Measurement baseline (same-orientation, same-bench, same-SIM): `qmicli --nas-get-signal-strength` + `mmcli -m` RAT/bands + `iw wlan0 scan` RSSI of a lab AP at fixed distance + GNSS cold TTFF open-sky (ch.04 §10 method) — all five captured at IQC (§16) as the unit's RF fingerprint; later "radio got worse" claims diff against the fingerprint (ambient/antenna-orientation noted per power-honesty rules ch.10 §8 — measurements without conditions are anecdotes). RF-shield bag checks (§13) + conducted-vs-radiated note (lab numbers are radiated-bench unless a conducted jig exists — conducted claims without a jig are rejected in review like datasheet-copied backlight curves ch.06 §11).

Modem-firmware-to-RF coupling: every modem FW change (vendor drop ch.04 §23) re-runs the five-measure fingerprint on the same unit + same bench (FW revs move RF tables silently — the diff, not the absolute, is the signal). Antenna-damage RMA (§18) appends post-repair fingerprint (repair verified by measurement, not "looks fine").

## 21. Cable/charger/adapter qualification (the 30% that masquerades as device bugs)

Problem restated (§11/§13 companion): roughly a third of "flaky device" reports trace to cables, chargers, or UART adapters — this section makes the bench prove accessories innocent before the device stands trial. Cable acceptance (per cable serial, logged in `hw/cable-log.csv`): continuity + CC-line correctness (USB-C CC pull-down/pull-up per spec — wrong CC resistors cause orientation-dependent fastboot failures ch.03 §15; test both orientations with C-to-C and C-to-A per §15 procedure), sustained data smoke (10 consecutive `fastboot getvar all` + one full `boot.img` transfer without retry lines in host `dmesg`), PD negotiation (USB-PD tester: advertised profiles vs label claim — overrated 100W-labeled 60W cables derated in the log with photo, not trusted). Charger acceptance: PD-profile advertisement check + loaded-voltage stability (5V/9V rails under phone-charging load measured with PD meter — sag >5% fails; sagging chargers produce "modem resets under load" ghosts that waste modem-bringup weeks). UART adapter acceptance: loopback test at 115200 8n1 + driver-version pin per host OS (§13 — adapter-driver updates re-run loopback before touching a unit; timestamped `tio --log` sample archived per adapter so corrupt-timestamp mysteries have a reference).

Quarantine rule: failed accessories labeled DESTROY (§13 — physically cut or sharpied + photo in cable-log; drawer-returned killers re-enter circulation within a month, guaranteed). Golden set: 3 cables + 2 chargers + 2 UART adapters marked GOLDEN (passed quarterly re-qual; bisect §21 + power calibration ch.10 §8 + RF fingerprint §20 run on golden accessories only — unqualified-accessory measurements carry `ACCESSORY-UNQUALIFIED` flag and can't gate). Procurement: bulk cable orders sample-tested 1-in-5 (lot failure >20% rejects the lot with vendor scorecard entry §18 — cheap-cable false economy ends here).

## 22. Board-revision tracking (silent PCB revs break DT assumptions)

Vendor board revisions (same model, different PCB rev — regulators re-routed, touch IRQ moved, panel second-sourced §15 bundled silently) get revision rows in the SKU record (§2 template extension `PCB-rev:` + `BOM-rev:`): revision identified from fastboot/`getvar` + physical sticker photo + kernel `dmesg` regulator/pinctrl probe diff vs golden (§11 stock-boot log is per-revision, not per-model — one golden per PCB rev). DT impact triage per new revision: `diff <(fdtdump golden-revA.dtb) <(fdtdump revB-stock.dtb)` vendor-DT side + our overlay `verify` (pinctrl state names, regulator labels, IRQ GPIOs re-checked — moved-IRQ with stale overlay = dead touch filed as "FW regression" without this step). Revision promotion mirrors §15 packet discipline at reduced scope (2-unit sample + panel/touch 5-step + modem ladder steps 1–3); un-triaged revisions marked `PCB-UNTESTED` bold (same rendering discipline as UNTESTED §12/§19 — honesty has one font).

## 23. ESD/handling discipline (static kills boards that then waste bisect weeks)

Bench rule: ESD mat + wrist strap for any open-device work (panel/battery/USB-board swaps §18/RMA §18); mats tested quarterly (resistance log with meter ID §13 — untested mats are decorations). Handling: battery-disconnect-first before any flex unplug (live-flex pulls spike rails and the corpse presents as "PMIC died randomly" — disconnect order in every swap procedure, violation noted in traveler §17 damage log); dropped-unit protocol (drop → visual + IQC spot subset §16 steps 5–7 re-run before the unit rejoins any gate — undocumented drops that later flake waste bisect jobs ch.03 §21 chasing hardware ghosts with software tools).

## 24. Manufacturing-variance acceptance (tolerance windows per peripheral + sample plan)

No two phones are the same phone: panel brightness, touch residuals, battery capacity, speaker sensitivity, vibrator strength, and UFS throughput all vary lot-to-lot and unit-to-unit. This section sets the tolerance windows that decide PASS/CONDITIONAL/FAIL at IQC (§16) and 2ND-SOURCE (§15) so judgments are repeatable, not arguer-dependent. Windows (per SKU, recorded in `hw/<sku>/VARIANCE.md`, calibrated from the first 5 IQC units + vendor datasheet — windows copied from another SKU without re-measurement are rejected in review): display 5-point nits within ±15% of `panel.json` golden (same lux meter §13 + same ambient per ch.10 §8 honesty rules; meter serial recorded or the reading is anecdotal), touch residual <8px on the 200-tap CSV (ch.06 §7 method — same matrix math, variance judged on numbers not feel), battery `full_charge_capacity` ≥95% design at 0.2C on calibrated meter with across-sample spread ≤5% (spread above signals lot trouble even when every unit passes absolute — reject-the-lot rule §15 applies), audio speaker loopback level within ±3dB of `tinymix` baseline (§9 dumps — mic/speaker mapping photo proves the same topology was measured), UFS sequential read within ±20% of SKU baseline (`fio` 1GB sequential, same governor + thermal state — hot-chip numbers don't count), suspend current within ±15% of power-calibration baseline (ch.10 §8 conditions restated per reading).

Sample plan: full 5-unit packet for any new lot/vendor/revision (no reduction by familiarity — "same vendor" without a lot code is not the same lot); 1-in-5 sampling for bulk accessories (ch.02 §21 golden-set rule); single-unit spot for traveler-role changes (§17 dogfood↔bench moves re-run panel+power spot only). Disposition mapping: all-windows-pass = PASS (enter traveler §17); one window marginal (≤5pp beyond window with a BUG link + expiry) = CONDITIONAL (named limitation travels with the unit — e.g., "dim panel −18%: brightness tests exempt, dogfood allowed"); any window breached beyond marginal or two marginals = FAIL (quarantine + RMA case §18). Variance data feeds the monthly flash+IQC+RMA joint review (§§11/16/18): repeat marginals from one vendor become a scorecard entry (§18) and a 2ND-SOURCE bar-raising proposal (§15 LESSON paragraph — variance tracked without loopback is statistics theater).

## 25. Second-source display/touch qualification sprints (time-boxed, two outcomes)

Full 2ND-SOURCE packets (§15) are thorough and slow; when supply forces a fast panel or touch substitution, run this 2-week sprint instead of improvising — it is the only sanctioned shortcut, with a 30-day expiry that forces the full packet afterward (§15 emergency-substitution rule made executable). Sprint team: BSP owner + QA bench tech (named pair, no handoffs mid-sprint — handoff halves the 2 weeks into status meetings). Day 1–2: datasheet delta one-pager (§15 item 1) + install on sacrificial unit (§17 role rule — never first-install an unknown panel on dogfood) + panel/touch 5-step (appendix-03A §4) with logs committed. Day 3–5: `panel.json` variant file (never overwrite variant A §15) + brightness 5-point curve + touch-residual CSV + DSI error soak 24h (`dmesg | grep -ci dsi.*err` must read 0). Day 6–8: power calibration delta (backlight curve + touch idle per §15 item 4; >10% delta escalates to Arch same-day, sprint pauses — power surprises don't timebox). Day 9–10: 72h soak overlap (suspend cycles + display on/off + one charge cycle, zero P0 §15 item 6) + dogfood-volunteer smoke (one experienced tester, 48h, exit micro-interview 15 min — "would you keep this panel" with reason).

Outcomes (exactly two, recorded in `hw/2ND-SOURCE/<part>-<date>/SPRINT.md`): SPRINT-PASS (time-boxed approval, 30-day expiry, full 5-unit packet due before expiry or variant demotes to UNTESTED-bold §12 — expiry enforced by calendar bot ch.11 §15, not memory) or SPRINT-FAIL (part quarantined with REJECT photo §15; failure reason maps to a variance-window tightening proposal §24, not just a shrug). Sprint anti-patterns (gate-review fails): skipping the power-delta re-measure ("same connector so same power" — connector equality never implied power equality), overwriting variant-A calibration with variant-B numbers (destroys the oracle for every A unit in the field), running the sprint on golden-accessory-substitutes without flagging `ACCESSORY-UNQUALIFIED` (§21 — unqualified measurements can't bless). Sprint velocity metric (tracked in program metrics ch.11 §11 quality set): sprints-per-quarter + full-packet conversion rate (rising sprints with falling conversions means supply chaos — escalate to procurement §7 quantities, not faster sprints).

## 26. Storage-UFS vendor variance handling (the silent benchmark mover)

UFS parts vary by vendor (Samsung/Micron/SK Hynix/Kioxia bins), firmware rev, and provisioned LUN geometry even under identical part numbers — and the variance moves boot time, OTA apply time, app cold-start (§16 ruler `halide-app-launch`), and encryption throughput (§7 AES-256-XTS). Policy: UFS vendor + firmware rev is a recorded dimension of the SKU record (§2 template extension `UFS: <vendor model + fw rev + LUN map>`), captured at IQC (§16 `lsblk` + `ufshcd stats` dumps) and re-captured on every modem/blob FW change (FW bundles silently carry UFS FW — fingerprint diff §20 pattern applied to storage). Handling per variance class: (a) geometry differences (LUN sizes, block alignment) → `flashmap.json` slot math recomputed per variant (ch.03 §18 size-guard wrapper refuses cross-geometry flashes — test the refusal per UFS variant exactly like §19 DRAM/UFS fork procedure; flashing a 128GB map onto 64GB is the classic brick the guard exists to refuse); (b) throughput differences within ±20% window (§24) → recorded as baseline fork in `hw/<variant>/ufs-baseline.md` (`fio` sequential+random 4K, `cryptsetup benchmark` AES-XTS, OTA-apply timing on fixed payload — same thermal state, same governor, same SoC frequency lock or the numbers are incomparable); (c) throughput beyond window or error counters (`ecc_corrected`, `link_startup_fail`, `hibern8_exit` errors in `ufshcd stats`) → RMA-adjacent case (§18 case file with stats excerpt + lot code) + lot-hold (no further units from that lot enter travelers §17 until the case closes with LESSON or NO-CHANGE).

OTA and filesystem coupling (why storage variance is a release issue, not a lab curiosity): `update_engine` payload apply is I/O-bound on slow UFS (staged-rollout timing ch.09 assumes a throughput floor — floor defined per SKU from the slowest accepted UFS variant, not the fastest lab unit), `fstrim` scheduling (§7) validated on the slowest variant (trim stalls that pass on fast flash fail dogfood on slow flash), encryption-first-boot formatting time measured per variant (first-boot ≤6 min budget ch.01 §18 must hold on the slowest accepted UFS — fastest-only proof is gate-review fail). Longevity: health descriptors (`bDeviceLifeTimeEstA/B`, `bPreEOLInfo`) sampled at IQC + quarterly on dogfood units (worn-flash units demote to bench-only before they become field anecdotes — traveler role change §17 with reason "flash wear"); failed-health units follow battery-disposal-analogous e-waste handling (never trash-with-data — crypto-erase attestation ch.08 before decommission, recorded in case file).

## 27. Connector/cable qualification list (approved parts, retired parts, golden set)

Lab reproducibility dies at the connector: USB-C receptacle wear, pogo/U.FL mating cycles, UART header fretting, and cable CC-resistor lies (§21) together cause the 30% (§11). This list (`hw/CONNECTORS.md`, owner Lab-kept ch.11 §2 QA row, reviewed quarterly with §13 upkeep) is the single source of truth: APPROVED table (part, vendor, spec claim, acceptance evidence link: cable-log §21 rows, charger PD-tester captures, UART loopback archives), GOLDEN set (§21: 3 cables + 2 chargers + 2 UART adapters by serial — gate measurements run on golden only), RETIRED table (serial + failure mode + DESTROY photo — retired parts never re-enter; drawer-return is how ghosts reproduce). Qualification per class: USB-C cables (continuity + CC-line both orientations + 10× `fastboot getvar all` + full `boot.img` transfer + PD-profile-vs-label check §21 procedure — overrated labels derated in the log with photo); chargers (advertised-profile check + loaded-rail sag ≤5% under phone load with PD meter — sagging chargers blamed for "modem resets" are retired here, not debugged as modem bugs); UART adapters (loopback at 115200 8n1 + driver-version pin per host OS §13 + archived `tio --log` timestamp sample); receptacle/pogo health (tray-swap count log §20 — 50-swap wear check; intermittent-SIM ghosts without tray log are bounced to the log before the modem team); RF-bag integrity (phone-inside-call-it test §13 — rings = retire).

Coupling to gates and forensics: power calibration (ch.10 §8) + RF fingerprint (§20) + bisect jobs (ch.03 §21) carry an `ACCESSORY-SET:` line naming golden serials (unqualified-accessory measurements flagged `ACCESSORY-UNQUALIFIED` per §21 cannot gate); flash-log cable serials (§11 column 9) join against this list monthly (top-killer cables identified by data, retired by rule: >2 attributed failures per quarter = auto-retire + vendor scorecard entry §18); RMA triage step 2 (§18 accessory-exclusion) consumes the golden set directly (swap-with-known-good means golden, not "another cable from the drawer"). Procurement discipline: bulk orders sample-tested 1-in-5 (§21), lot failure >20% rejects the lot (scorecard entry — cheap-cable economy ends here per §21 text, enforced at this list, not wished at standup).

## 28. Field-failure HW revision forensics (from corpse to preventive change)

When a dogfood or bench unit dies or degrades in the field (no-boot, modem-dead, panel lines, swelling, intermittent USB-C, "radio got worse"), this procedure turns the corpse into a preventive change — appendix to the §18 RMA loopback, not a replacement: RMA opens the case, forensics closes the learning. Forensic capture (before any repair flash — repair-before-capture destroys evidence; violation noted in traveler §17): (1) freeze the traveler + flash-log tail (§§17/11 — last-known-good build + last procedure), (2) UART/pstore/ramoops pull (ch.03 §9 pstore path per DRAM variant §19 — wrong-variant addresses read garbage, re-validate), (3) RF fingerprint diff (§20 five measures vs IQC baseline — "radio worse" quantified or withdrawn), (4) power/thermal snapshot (suspend current + thermal zones §6 envelope — swollen-battery units skip charge steps, safety first, photo + e-waste path), (5) board-revision triage (§22: PCB-rev sticker photo + `fdtdump` diff vs golden — silent rev changes caught here when IQC missed them), (6) accessory exclusion (§18 ladder step 2 with golden set §27 — 30% rule applied before silicon blamed), (7) storage health (`ufshcd stats` + lifetime descriptors §26 — worn-flash deaths filed as wear, not mysteries).

Revision verdicts (exactly one per closed case, recorded in `hw/rma/<unit>-<date>/FORENSICS.md`): SINGLE-UNIT (damage/wear/drop with traveler evidence — no tree change, damage log updated §17), LOT-ISSUE (≥2 same-lot failures same mode in a quarter — triggers lot-hold §26 + vendor scorecard §18 + variance-window tightening proposal §24), REVISION-ISSUE (PCB/BOM-rev correlated — triggers §22 revision row + overlay re-verify + promotion packet for the newly discovered revision; un-triaged revisions marked `PCB-UNTESTED` bold), DESIGN-ISSUE (envelope or procedure wrong — thermal trip, charge current, handling order §23 — triggers DT/overlay fix or procedure amendment with ADR where architecturally significant ch.11 §14). Every verdict carries a `LESSON:` → linked change (§18 loopback rule restated with teeth: forensics without a linked IQC/traveler/2ND-SOURCE/flash-map/procedure change, or an explicit `NO-CHANGE:` with reason, fails the monthly RMA review). Trend output: top-3 modes per 100 device-weeks (§18) published in the monthly release-train review (ch.11 §15 calendar) — repeat modes twice in a quarter become P1 engineering bugs with owner + date, never "bad luck."

## 29. PMIC regulator audit procedure (every rail named, every volt measured, every suspend-drop caught)

Purpose: silent regulator drift (wrong voltage, missing suspend-drop, re-parented consumer after a DT edit or board rev §22) presents as modem flakiness, panel flicker, UFS errors, or "battery regression" — this procedure makes the power tree auditable per SKU-revision-UFS-variant (§§12/19/26 dimensions recorded on every run, never a bare SKU). Frequency: at IQC baseline (§16) for each new unit, after every DT/overlay change touching `regulator-*`/`power-domains`, after every board-rev triage (§22), after every modem/UFS FW bundle (§§20/26 fingerprint rule extended to rails), and quarterly on dogfood units (traveler-linked §17). Tooling: host `adb`/UART shell + `halide-regaudit` wrapper (commits dumps + diffs vs golden; hand-`cat` without the wrapper is reconnaissance, not an audit).

Step 1 — capture (running, screen-on idle, golden accessories §27, charger state recorded — charging vs battery changes bucks silently):

```bash
UNIT=HALIDE-A1 SKU=refA-eu-6-128 REV=$(cat hw/<sku>/PCB-REV 2>/dev/null || echo unknown)
OUT=hw/<sku>/dumps/$(date +%F)/regulator-$UNIT
mkdir -p "$OUT"
cat /sys/kernel/debug/regulator/regulator_summary > "$OUT/regulator_summary.txt"
cat /sys/kernel/debug/pm_genpd/pm_genpd_summary > "$OUT/pm_genpd_summary.txt"
cat /sys/kernel/debug/clk/clk_summary > "$OUT/clk_summary.txt" 2>/dev/null
for z in /sys/class/thermal/thermal_zone*/{type,temp}; do echo "== $z"; cat "$z"; done > "$OUT/thermal.txt"
cat /sys/class/power_supply/battery/{voltage_now,current_now,capacity,status} > "$OUT/battery.txt" 2>/dev/null
dmesg | grep -i -e regulator -e pmic -e avs -e cpr -e gdsc > "$OUT/dmesg-regulator.txt"
halide-regaudit --meta "unit=$UNIT sku=$SKU pcb=$REV ufs=$(cat hw/<sku>/UFS-REV 2>/dev/null) accessory-set=$(cat hw/GOLDEN-SET)" --out "$OUT"
```

Step 2 — rails table (per-SKU golden lives at `hw/<sku>/REGULATORS.md` + machine-readable `hw/<sku>/regulators.json`; first audit on a new SKU/revision creates it from datasheet + stock-boot log §11 + mainline `regulator_summary` — datasheet-copied numbers without measured confirmation flagged `UNMEASURED` exactly like `ACCESSORY-UNQUALIFIED` §21, never trusted for gates):

| Rail (summary name) | PMIC:output | Nominal (datasheet) | Measured sysfs (`microvolts`) | Consumers (DT `*-supply`) | Suspend expectation |
|---------------------|-------------|---------------------|-------------------------------|---------------------------|---------------------|
| `vddcx` | PMI8998:S2 | 800–1100mV (AVS) | `cat /sys/class/regulator/regulator.<N>/microvolts` | CX domain, GPU-GDSC parent | AVS-down, never off |
| `vddmx` | PMI8998:S1 | 800–1100mV (AVS) | same node | MX/MSS/modem fabric | AVS-down, modem-ladder §3 re-check if moved |
| `vdda-bl` / `wled` | PMI8998:WLED | panel-curve (panel.json ch.06 §11) | `brightness` 0/51/102/153/204/255 sweep + meter nits | backlight string | drop-to-retention, 0 DSI errs (§15 bar) |
| `vccq/vcc` (UFS) | discrete/LDO | 1.2V/2.9V class | summary + `ufshcd stats` joint capture | UFS LUNs (§26 coupling) | retention per §26 health read |
| `vddpx-ufs`/`vccq2` | PMIC:LDO | board-schematic value | summary line + probe note | UFS PHY | off-allowed only if link re-inits ≤ budget (boot-time §7 cap) |
| `touch-vdd/vcc-i2c` | PMIC:LDO pair | touch datasheet (2ND-SOURCE packet §15) | summary + touch-idle current (meter §13) | touch controller + IRQ pull | suspend-drop per FW rev (FW bumps re-audit — §15 palm-curve lesson) |

Step 3 — suspend-drop checks (the audit's point: rails that stay up, consumers that vote wrong, wakeups that pin bucks): `echo mem > /sys/power/state` instrumented cycle ×10 (UART log §11 running — suspend-entry `PM: suspend entry (deep)` + `PM: suspend exit` timestamps per ch.03 §21 bisect format), with `regulator_summary` captured pre-suspend, at 60s suspend (via `rtcwake -m mem -s 60` so capture is scripted, not hand-timed), and post-resume; PASS bars: every `SUSPEND-DROP-EXPECTED` rail reads 0/off or retention per table (any full-on rail = FAIL with consumer + `pm_genpd_summary` voter named — "regulator stayed on" without the voter is an observation, not a finding), resume restores all `microvolts` within ±2% of pre-suspend (beyond = P1 with `dmesg-regulator.txt` excerpt + traveler entry §17), overnight suspend current within the §24 variance window (±15% of calibration baseline, same meter §13 + same ambient ch.10 §8 — otherwise `ACCESSORY-UNQUALIFIED`), zero `under-voltage`/`over-current` lines in post-resume `dmesg`. Diff-vs-golden: `halide-regaudit diff --golden hw/<sku>/regulators.json --new "$OUT"` fails on added/removed rails, renamed consumers, or >3% nominal drift (board-rev silent changes §22 caught here when `fdtdump` diff was skipped — the auditor that catches the skipped step earns its keep).

Artifacts + loopback: `$OUT/` committed under `hw/<sku>/dumps/<date>/` with `DUMP-PROCEDURE.md` command lines (§9 rule — re-runnable by anyone holding the unit); golden updates via MR only (BSP + QA sign, §15 packet discipline for 2ND-SOURCE-driven rail changes, §22 revision-row update for PCB-driven changes); every FAIL opens a bug with rail + voter + meter serial + `ACCESSORY-SET:` line (§27) and a `LESSON:` target (DT fix, variance-window tightening §24, or RMA case §18). Verification: wrapper exit 0 + golden-diff clean + 10-cycle suspend log with entry/exit lines + battery-idle sanity (§16 step 7) on the same run — audits missing any leg are INCOMPLETE, not CONDITIONAL (§16 disposition vocabulary reused deliberately).

## 30. Display/touch second-source delta checklist (glass differs silently — measure, don't assume)

Scope: any panel or touch substitution vs the qualified primary (new glass vendor, same-vendor lot change with new panel ID, touch FW rev bump, backlight-driver swap WLED-vs-lab-boost) — triggers the §15 packet (full) or §25 sprint (time-boxed, 30-day expiry), and this checklist is the bench procedure both paths execute. Principle (stated once, enforced everywhere in this chapter): panel ID equality never implies brightness-curve equality, touch-name equality never implies palm-curve equality, connector equality never implies power equality (§25 anti-patterns restated as checklist guards — the checklist refuses to run when its preconditions are violated).

Preconditions (GO/NO-GO, recorded at the top of `hw/2ND-SOURCE/<part>-<date>/DELTA.md`): sacrificial unit assigned (§17 — never first-install on dogfood; violation aborts the run and is noted in the traveler), golden accessories only (§27 serials listed; substitutes flag the entire run `ACCESSORY-UNQUALIFIED` per §21 — unqualified runs inform, never bless), stock-boot golden for this PCB-rev exists (§22 — without the oracle there is nothing to delta against), `panel.json` variant file created (never overwrite variant A §15 — checklist step 1 verifies `git status` shows a NEW file, not a modification), touch FW version pinned in BLOBS.md (§15 + §4 blob policy — unpinned FW measured is unrepeatable data).

| # | Check | Method (exact commands / conditions) | PASS bar | On FAIL |
|---|-------|--------------------------------------|----------|---------|
| D1 | Panel ID + DSI mode read | `dmesg \| grep -i panel` + `modetest -M msm` mode line + `fdtdump` DSI-timing diff vs golden (§22) | ID recorded as new variant row (§12); mode matches overlay `verify` (mismatch-halt ch.06 §11 honored — halt is success of the guard, not failure of the part) | overlay fix MR or REJECT (§15 rejected-lot photo + reason) |
| D2 | Brightness 5-point curve | lux meter §13 (serial recorded) + `brightness` 0/51/102/153/204/255 sweep, same ambient per ch.10 §8 | within ±15% of `panel.json` at all 5 points (§24 window) or new variant file values with Arch sign | new `panel.json` variant vs lot-reject decision (§15 battery-analogous spread rule: >5pp spread across 5 samples = lot trouble) |
| D3 | Dead-pixel + flicker + uniformity | solid-color screens (R/G/B/W/K) visual + 240fps phone-camera flicker check (ch.03 §13 method) + 9-zone lux spread | zero stuck/dead, no PWM-band flicker above stock baseline, uniformity within datasheet | quarantine + vendor scorecard entry (§18) |
| D4 | DSI error soak 24h | display on/off script + suspend cycles overlapping (§15 item 6), `dmesg \| grep -ci dsi.*err` | exactly 0 over soak | REJECT (DSI errors never CONDITIONAL — §16 disposition mapping has no marginal for error counters) |
| D5 | Touch 200-tap residual CSV | ch.06 §7 SEQ-joined method (same matrix math — variance judged on numbers §24, not feel) + 10-finger `evtest` slots | residual <8px, slots all present, <3 drops per 100-swipe false-reject run (§15 bar) | touch-matrix refit MR or FW-pin revert + re-run (FW revs change palm curves §15 — re-validate heuristic, don't argue feel) |
| D6 | Touch FW + IRQ/pinctrl | FW version read + `fdtdump` IRQ-GPIO vs overlay (moved-IRQ §22 trap) + suspend palm-reject smoke (10 pocket-sim cycles) | FW == BLOBS.md pin; IRQ matches overlay; zero pocket-dial wakes | board-rev triage packet (§22) before any panel verdict |
| D7 | Power delta (backlight + touch idle) | backlight curve power + touch-idle current on calibrated meter §13 (charging-state labeled per §29 step 1) | ≤10% vs primary or Arch same-day review (§15 item 4 / §25 day 6–8 pause rule) | power-gate hold — supply pressure never overrides (§25 sprint expiry still applies) |
| D8 | Coexist + thermal spot | Wi-Fi/BT coexist re-measure (§12 discount trio) + skin-temp spot under max-brightness video 15 min (§13 camera bar ±2°C) | no new coexist regression vs §9 baseline dumps; thermal within §6 envelope | RF-path note (§20) + thermal trip review (DESIGN-ISSUE verdict path §28) |
| D9 | 72h soak + dogfood smoke | suspend cycles + display on/off + one charge cycle, zero P0 (§15 item 6) + 48h volunteer smoke + 15-min exit micro-interview (§25 day 9–10) | 0 P0; volunteer "would keep" with reason recorded | SPRINT-FAIL verdict (§25) with variance-tightening proposal (§24), not a shrug |

Close-out (no packet without it): `DELTA.md` committed with every command line + meter/cable/accessory serials (§§13/21/27 — readings without serials are anecdotes per §24), variant record row (§2 template) + `panel.json` variant + BLOBS.md FW pin linked, release-notes line ("variant B glass supported from vX.Y" §15) drafted, full-5-unit-packet due date set for sprint path (calendar-bot enforced §25 — expiry demotes to UNTESTED-bold §12 automatically). Verification: DELTA.md 9/9 rows dispositioned PASS/REJECT (no blanks, no CONDITIONAL on D4), golden-diff + traveler + flash-log updated same day (§§11/17 staleness rules), monthly joint review (§§11/16/18) sees the packet — invisible qualifications do not bless variants.

## Verification

- [ ] REF-A + REF-B records filled, blob SHAs recorded.
- [ ] UART boot log archived; stock GPT backup verified restorable.
- [ ] `modetest` + `evtest` + `qmicli --dms-get-ids` outputs archived per SKU.
- [ ] Every active unit has a traveler with QR label; quarterly audit green (zero unlabeled units).
- [ ] 2ND-SOURCE packet exists for each non-primary part in any shipping variant (no packet-less BOM).
- [ ] `hw/iqc-log.csv` covers 100% of active units; RMA cases carry LESSON or NO-CHANGE lines.

Next: `03-kernel-gki-bootloader.md`.
