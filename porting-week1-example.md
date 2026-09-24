# Worked Example — Porting Week 1: UART Shell on an SDM845-Adjacent Board
**Parent: ch.11 §8 porting guide · Redacted real-shape log (timestamps/IDs illustrative, commands exact)**

## Day 1 — Backup & inventory (no flashes today)

```bash
adb devices                      # stock ROM, authorized — Expected: device listed
adb pull /dev/block/by-name/persist persist-backup/   # + modemst1/2, efs where present
adb shell 'ls -l /dev/block/by-name/ | tee gpt-map.txt'
fastboot getvar all 2>&1 | tee fastboot-vars.txt     # bootloader version recorded
# UART: 115200 8n1 on marked pads (photo hw/<sku>/uart.jpg) — capture stock boot:
tio /dev/ttyUSB0 --baudrate 115200 --log stock-boot.log
```

Expected: full stock boot visible incl. `ABL` lines + kernel `Linux version 4.9.x-qgki` (stock base noted for blob provenance). Gotcha hit (real): USB-serial adapter defaulted 9600 — garbage until fixed; documented in DUMP-PROCEDURE so the next porter doesn't lose an hour.

## Day 2 — Defconfig fragment + DT overlay skeleton

```bash
cp devices/sdm845-refa/halide-refa.fragment devices/sdm845-new/halide-new.fragment
# edit: only panel + touch deltas (everything else inherits halide-base)
dtc -I dts -O dtb -o test.dtb devices/sdm845-new/dts/10-minimal.dtsi && fdtdump test.dtb | head
```

Build kernel per ch.03 §11 (defconfig+dtbs only — no full Image yet; fast feedback). Gotcha: overlay referenced `vreg_l14a` but this variant's panel IO is `vreg_l12a` (stock dump line cited) — fixed with SRC comment.

## Day 3 — First fastboot boot (no flash — RAM only)

```bash
fastboot boot out/sdm845-new/boot.img   # Expected: UART shows HALIDE kernel boot
# watch for: "Run /init as init process" then systemd banner
```

First attempt: EDL loop (DTB load overlap — ch.03 §10 classic). Fix: corrected DTB address per §2 memory-map procedure (stock `fastboot getvar` + ABL header math shown in commit message). Second attempt: systemd login prompt on UART. Phase-1 week-1 acceptance (ch.11 §8) met: UART shell, `uname -r` + `ls /dev/binder*` green.

## Day 4 — Dumps & upstreaming ledger entry

Captured `modetest` (connector present, panel dark — expected, timings next week), `qrtr-lookup` (empty — rproc firmware paths next), regulator summary. Filed `kernel/TECH-DEBT.md` entry for the one out-of-tree touch quirk found (link-less TODO with 2026-10 review date per ch.03 §20). Pushed branch `port/sdm845-new-w1` with logs + photos; office-hours review Friday confirmed week-2 plan (panel timings → touch IRQ).

## Lessons encoded (why this file exists)

1. Never flash before backup + UART (2 bricked-port postmortems in other projects — our ritual prevents all three).
2. `fastboot boot` before `fastboot flash` (RAM-only first — always).
3. One subsystem per overlay file (§1 map) so review catches the `l14a/l12a` class of mistake by diff locality.
4. Log everything with commands (this file's shape is the template: command → Expected → gotcha → fix-with-source).

## Verification

- [ ] Reviewer reproduces week-1 result from this file alone on a second unit (annual fresh-eyes test, ch.01 P4 story).
