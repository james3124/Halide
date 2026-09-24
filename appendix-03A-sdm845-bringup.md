# Appendix 03-A — REF-A (SDM845) Device-Tree & Bring-Up Notes
**Parent: ch.02, ch.03 · Status: living doc — update per boot, not per release**

## 1. Base & overlay map

Base: mainline `arch/arm64/boot/dts/qcom/sdm845.dtsi` + board file matching REF-A variant (e.g., `sdm845-oneplus6.dts` where available; else closest + overlay). Overlays in `devices/<sku>/dts/` (one file per subsystem — reviewable diffs, not a monolith):

```
devices/sdm845-refa/dts/
  10-regulators.dtsi   # rpmh vreg min/max + always-on justification per rail
  20-pinctrl.dtsi      # default+sleep states per peripheral
  30-panel-touch.dtsi  # DSI panel + backlight + touch (IRQ, fw name)
  40-audio.dtsi        # WCD934x + WSA881x + mic topology + jack
  50-camera.dtsi       # CAMSS + sensor nodes + flash + eeprom
  60-sensors.dtsi      # IIO accel/gyro/mag/pressure/als/prox thresholds
  70-modem.dtsi        # rproc/mpss + qrtr + rmnet + SIM detect
  80-battery.dtsi      # charger + gauge + thermal zones + trips
  90-debug.dtsi        # eng-only: kgdboc, extra UART, ramoops carveout (never release)
```

Provenance rule (ch.03 §13): every node/property carries `/* SRC: stock-dump|datasheet-pNN|measured-YYYYMMDD */`. Review rejects unsourced lines.

## 2. Memory map (SKU-specific — fill from stock bootloader dump)

```
DRAM:            0x80000000 – <top per RAM SKU, 6G/8G variants differ!>
ABL load:        per stock fastboot info dump
kernel Image:    0x80080000 (verify vs ABL bootimg hdr)
ramdisk:         follows kernel (avoid DTB overlap — the classic EDL-loop cause, ch.03 §10)
DTB:             <addr> (align 2M)
ramoops:         <addr size 1M> reserved via memreserve (no-mmap in overlay)
modem fw:        carved by XBL (do not describe — document reservation only)
```

Two RAM variants = two verified maps (6GB and 8GB tested separately; untested variant is labeled UNTESTED, not assumed).

## 3. Regulator audit (idle-power gate dependency)

Table per rail (`regulator_summary` + meter): name, min/max µV, consumers, always-on? (with justification or removal date), measured drop in sleep. Known trap: `vreg_l14a` (panel IO) left always-on hides a missing DSI vote AND costs ~8mA — verify rail actually gates on panel-off (`/sys/kernel/debug/regulator/.../use_count` → 0). Audit script `scripts/regulator-audit.sh` diffs against `hw/<sku>/regulator-baseline.txt`; any new always-on blocks Phase-3 power gate.

## 4. Panel & touch bring-up sequence (order matters)

1. Backlight-only (WLED on, DSI off): confirm PWM + current with meter (isolates power from protocol).
2. `simple-panel` + fixed timings: any image? (isolates driver vs timings).
3. Full panel driver with stock timings from dump; `modetest -M msm` must list mode; photograph splash + record `dmesg` DSI lines.
4. Touch IRQ enumerated (`/proc/interrupts` count grows on tap) before multitouch (`evtest` slots) before matrix calibration (ch.06 §7 procedure, residual committed here: `hw/<sku>/input-matrix.conf` + residual value).
5. Suspend/resume with display 20 cycles before composer integration (isolates panel power from graphics stack).

## 5. RPROC & firmware inventory (exact paths)

`adsp: qcom/sdm845/adsp.mbn`, `cdsp: .../cdsp.mbn`, `mpss: .../mpss.mbn` (+ version + SHA in `BLOB-SHA256.txt`), `wcn3990: wlanmdsp.mbn + bdwlan.*`, touch `touch_fw.bin v12`. `rproc` state expectations after boot: adsp/cdsp/mpss `running`; check `dmesg | grep -i -e pas -e rproc` for auth failures (PAS auth fail = silent DSP death, ch.03 §13). Firmware load order logged with timestamps (`dmesg` delta adsp→cdsp→mpss recorded — order drift across releases is investigated, not ignored).

## 6. Known REF-A quirks (living list — append, never delete)

1. DSI link needs re-train after 3rd suspend on variant A panels (workaround: ch.06 §9 rotation lock; fix tracked BUG-xxx).
2. WCN3990 BT SCO needs `btattach` quirk flag on cold boot (warm reboot fine — cold-only bugs get their own test).
3. Gauge reports 3% low under 15°C (temperature compensation table in `80-battery.dtsi` comment + source).
4. Second SIM slot detect polarity inverted vs stock DT (measured 2026-04-30, photo in `hw/<sku>/sim-tray.jpg`).

## Verification

- [ ] Both RAM variants booted to systemd login with per-variant memory map archived.
- [ ] Regulator audit matches baseline; panel+touch 5-step sequence logged with photos.
- [ ] All rproc `running`; firmware SHAs match `BLOB-SHA256.txt`.
