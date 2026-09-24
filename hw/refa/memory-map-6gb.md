# memory-map-6gb.md - REF-A 6GB DRAM variant memory map (appendix-03A S2)
# Owner: BSP/Kernel. SEPARATE verified map - addresses recomputed per RAM size,
# never copied from the 4GB file (S30 sizing fork; ramoops range moves with top).
# See memory-map-4gb.md for the shared procedure (ABL/Image/ramdisk/DTB rules,
# S30 ritual, redaction scan). Only variant-specific values are repeated here.

```
DRAM:            0x80000000 - 0x1FFFFFFFF  (6GB: 0x1_80000000 bytes)
ABL load:        per stock fastboot info dump (archive `fastboot getvar all` per release, S18)
kernel Image:    0x80080000 (verify vs ABL bootimg hdr - same as 4GB, low RAM is identical)
ramdisk:         follows kernel (avoid DTB overlap - 2M align, check header vs flash map)
DTB:             0x81000000 (align 2M; same low placement as 4GB)
ramoops:         0x1FF00000 size 1M (0x100000) reserved via memreserve (no-mmap in overlay)
                 record split: console 0x20000 + dmesg 0x20000 + ftrace 0x10000 + pmsg 0x10000 (S30 minima)
modem fw:        carved by XBL (do not describe - reservation documented only)
```

## Variant delta vs 4GB (WHY a second file)
- DRAM top differs (0x1FFFFFFFF vs 0x17FFFFFFF); ramoops sits 1M below top in
  BOTH variants so low-memory layout (kernel/ramdisk/DTB) is identical and
  only the ramoops address + cmdline + DT reg move.
- cmdline ramoops.mem_address MUST differ per variant (registry S37:
  copied-across-variants values forbidden; S30 mismatch fails build).
- lmkd minfree tables differ per variant (power/refa/memory.md side-by-side).

## Status
- Variant 6GB: UNTESTED until booted to systemd login with this map archived
  (appendix-03A verification: both RAM variants booted separately).
- IOMEM dump: PENDING (builder commits /proc/iomem per variant).
