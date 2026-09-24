# edl.md - REF-A EDL (9008) entry + ABL/fastboot policy (ch.03 S18)
# Owner: BSP/Release. EDL is the LAST RESORT - flashing without a persist/EFS
# backup can brick calibration (WARNING below). Keep stock ABL where possible;
# HALIDE ABL changes limited to: A/B slot boot logic (misc metadata), fastboot
# oem halide-logs (pstore export over fastboot), unlock flow with persist/EFS
# backup prompt.

## EDL entry (REF-A)
- Method: volume-down + power 10s (resin) from powered-off, then USB plug;
  `lsusb` shows 05c6:9008 (Qualcomm HS-USB QDLoader 9008).
- Test-point photo: PENDING (appendix-03A requires photo or button combo per SKU).
- WARNING: EDL flashing without backup can brick calibration (persist/EFS).
  Always run the persist/EFS backup prompt flow before any EDL write.
- Resin (volume-down+power 10s) must hard-reset EVEN WITH kernel hung: test
  with `echo c > /proc/sysrq-trigger` + resin (eng) - device must reboot; if
  not, PMIC config wrong, P0 bug (S19).

## ABL / fastboot
- `fastboot getvar all` output archived per release (bootloader version drift
  detection, S18).
- DTBO bundle: mkdtboimg page_size 2048 version 1 (pinned per bootloader
  libufdt capability - S40). Bootloader libufdt applies exactly one overlay;
  log line `applied overlay id=<N>` single (S40).
- fastboot flash wrapper validates image sizes against
  images/refa/flashmap.json before touching the device (refuse on mismatch -
  prevents cross-SKU bricks, S18).

## Slot / rollback
- A/B slots (boot_a/boot_b, vendor_boot, vbmeta_a/b, dtbo, super, userdata).
- Dev: vbmeta --flag 0 (orange, verified boot off) for bring-up; release:
  --flag 2 (enforcing) required for Phase-3 gate (S6).
- Rollback: increment --rollback_index per release; test rollback rejection
  explicitly (flash old image -> must refuse to boot with event logged, S6).

## Verification
- [ ] EDL entry demonstrated on sacrificial (log + lsusb VID/PID archived).
- [ ] getvar archive per release; flash wrapper refuses oversized images.
- [ ] Rollback-rejection test green; resin hard-reset from hung kernel green.
