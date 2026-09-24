# cmdline-registry.md - REF-A kernel cmdline registry (ch.03 S37 NORMATIVE)
# Owner: Kernel/BSP. Every cmdline token in mkbootimg (S6) + DT bootargs +
# bootloader-appended androidboot.* MUST appear here. CI boot-lint greps the
# built boot.img cmdline against this table; unregistered tokens fail the build.
# Review: re-validate every LTS bump (S26) + every bootloader change (S18).
# Stale entries past one release get STALE- prefix + removal BUG.

| Param | Value | Owner | Why | Forbidden | Test |
|---|---|---|---|---|---|
| `console` | `ttyMSM0,115200n8` | Kernel | early bring-up + pstore-adjacent triage (S9) | `tty0`-only (loses pre-fb logs) | UART prompt on eng |
| `androidboot.hardware` | `qcom` / `halide-refa` | Android/BSP | HAL variant select (`ro.hardware`) | generic `default` (loads wrong audio/camera policy) | `getprop ro.hardware` matches SKU |
| `androidboot.memcg` | `1` | Kernel | AOSP lmkd cgroup accounting (S12 note) | `0` (lmkd blind) | lmkd PSI mode active |
| `cgroup.memory` | `nokmem` | Kernel | legacy AOSP lmkd quirk (S12 - TEMPORARY, removal release named in TECH-DEBT.md) | permanent w/o review date | ledger S20 entry cites this row |
| `printk.devkmsg` | `on` | Kernel | container `dmesg` visibility for triage | `off` on eng (blinds lab) | `logcat -b kernel` non-empty |
| `printk.time` | `1` | Kernel | boot-timeline joins (S28 - always-on) | `0` (unjoinable logs) | timeline tool parses |
| `initcall_debug` | present eng / absent release | Kernel | initcall ranking S29 | present on release (overhead + log spam) | release cmdline grep-absent in CI |
| `systemd.unified_cgroup_hierarchy` | `1` | Platform | cgroup-v2 single tree (S12) | `0` (v1 split breaks lmkd PSI) | `mount \| grep cgroup2` |
| `ramoops.mem_address` | per-variant S30 (see hw/refa/memory-map-*.md) | Kernel | must match DT (S30 mismatch fails build) | copied across RAM variants | S30 sysrq ritual per variant |
| `ramoops.mem_size` | per-variant S30 | Kernel | must match DT | copied across RAM variants | S30 sysrq ritual per variant |
| `ramoops.record_size` | per-variant S30 | Kernel | must match DT | undersized (truncates modem-active dmesg) | pstore files non-empty post-sysrq |
| `kgdboc` | eng-only (`ttyMSM0,115200`) | Kernel | early-debug S17 | any release presence (CI neverallow-eng analog) | release grep-absent |
| `kgdbwait` | eng-only | Kernel | early-debug S17 | any release presence | release grep-absent |
| `nowatchdog` | eng-kgdb-only | Kernel | S19 (release forbids) | release (CI grep) | watchdog pet log on release |
| `pcie_aspm` | `force` | Kernel/BSP | S35 ASPM policy | `off` w/o S35 power note | `power/refa/pcie.md` idle delta filed |
| `usbcore.autosuspend` | default `2` (per-interface policy normative, S35) | Kernel | S35; QMI quirk `-1` is per-interface, not global | global `-1` (kills suspend power) | suspend audit USB rows |
| `sched_energy_aware` | `1` iff energy-model present (S33) | Kernel | EAS honesty rule | `1` w/o model (fake EAS) | EAS counters under mix test |
| `dm-mod.create` | per-slot AVB S6 | Security | verified-boot chain | `verify=off` outside eng-orange | AVB green check ch.09 |
| `dm-verity` / `verity` | per-slot AVB S6 | Security | verified-boot chain | `verify=off` outside eng-orange | AVB green check ch.09 |
| `luks.*` / `rd.luks.*` | per LUKS2 ch.09 | Security | userdata encryption | `rd.luks=0` anywhere | encryption-state test |
| `androidboot.slot_suffix` | `_a` / `_b` (bootloader-set) | Bootloader | A/B (S6/S18) | hardcoded (breaks OTA slot) | slot-switch test preserves ramoops S30 |
| `audit` | `1` release | Security | MAC enforcing gate (S12) | `0` outside eng | `getenforce` both namespaces |
| `selinux` / `enforcing` | `enforcing=1` release | Security | MAC enforcing gate (S12) | `enforcing=0` outside eng | `getenforce` both namespaces |
| `loglevel` | `4` release / `7` eng | Kernel | release log-spam vs triage balance | `quiet` hiding ramoops-relevant oops | forced-warning appears in pstore |

## Bootloader-appended params (READ-ONLY inputs - kernel records expected sets)

| Param | Expected values | On unexpected |
|---|---|---|
| `androidboot.serialno` | unit serial (never committed to git) | log + continue (serial is informational) |
| `androidboot.bootreason` | `reboot,cold,watchdog,resin,alarm,crash` (pinned vocabulary) | `BOOTREASON-UNKNOWN` journal + BUG, never silently map to `cold` |
| `androidboot.verifiedbootstate` | `green` (release) / `orange` (eng) / `red` | `red` halts userspace pivot with pstore event; rollback-rejection case S6 covers |
| `androidboot.vbmeta.*` | digests matching `images/refa/flashmap.json` + vbmeta-info.txt | AVB red-equivalent handling per S40 layer 1 |
| `androidboot.dtbo` | `applied` / `missing` (S40 apply layer) | `missing` = panel fallback framebuffer + `DTBO-MISSING` banner, never panic |

## Worked mkbootimg cmdline (REF-A, S6 shape - values pinned by rows above)

```
console=ttyMSM0,115200n8 androidboot.hardware=halide-refa androidboot.memcg=1
cgroup.memory=nokmem printk.devkmsg=on printk.time=1
systemd.unified_cgroup_hierarchy=1 loglevel=7 audit=1 enforcing=1
```
(eng variant shown; release drops `initcall_debug`/`kgdboc`/`kgdbwait`/`nowatchdog`,
sets `loglevel=4`, adds per-variant `ramoops.*` + `pcie_aspm=force`.)

## Verification
- [ ] `boot-lint`: every token of the built boot.img cmdline has a row here.
- [ ] Release cmdline contains none of: `initcall_debug`, `kgdboc`, `kgdbwait`, `nowatchdog`.
- [ ] `ramoops.*` values equal the per-variant memory-map files.
- [ ] Registry re-validated at each LTS bump (S26 triage names renamed params).
