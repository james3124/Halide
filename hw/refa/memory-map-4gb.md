# memory-map-4gb.md - REF-A 4GB DRAM variant memory map (appendix-03A S2)
# Owner: BSP/Kernel. Filled from stock bootloader dump; NEVER copied across
# RAM variants (DRAM top differs - untested variant labeled UNTESTED, not assumed).
# The classic EDL-loop cause (ch.03 S10): DTB load address overlapping ramdisk.

```
DRAM:            0x80000000 - 0x17FFFFFFF  (4GB: 0x1_00000000 bytes)
ABL load:        per stock fastboot info dump (archive `fastboot getvar all` per release, S18)
kernel Image:    0x80080000 (verify vs ABL bootimg hdr)
ramdisk:         follows kernel (avoid DTB overlap - 2M align, check header vs flash map)
DTB:             0x81000000 (align 2M; overlaps nothing - EDL-loop guard S10)
ramoops:         0x17F00000 size 1M (0x100000) reserved via memreserve (no-mmap in overlay)
                 record split: console 0x20000 + dmesg 0x20000 + ftrace 0x10000 + pmsg 0x10000 (S30 minima)
modem fw:        carved by XBL (do not describe - reservation documented only)
```

## ramoops reservation proof (S30)
- `/proc/iomem` dump committed per variant: ramoops range marked reserved,
  zero overlap with System RAM executable regions, outside kernel memblock +
  CMA + modem-shared carveouts.
- DT binding: reserved-memory/ramoops node (compatible = "ramoops", reg +
  record-size properties, provenance-commented per S13) + cmdline
  belt-and-braces (ramoops.mem_address/size/record_size matching DT -
  mismatch boots but logs `ramoops: disagrees with DT` and boot-lint fails).
- Verification ritual per release (sacrificial, eng, charger attached, serial
  logging): `echo c > /proc/sysrq-trigger`, warm-reset, all three pstore
  files non-empty with sysrq signature; halide-early.service boot-id linkage
  (no orphans); survives 50-cycle suspend + OTA slot switch; redaction scan
  (no BEGIN PRIVATE / keymaster patterns - failure = Security P0).

## Status
- Variant 4GB: BOOTED to systemd login (date/log pending first HW run) / figures above from stock dump.
- IOMEM dump: PENDING (builder commits /proc/iomem per variant).
