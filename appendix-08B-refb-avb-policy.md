# Appendix 08-B — REF-B AVB Policy, Partitions & Slot Discipline
**Parent: appendix-08A (same shape, REF-B sizes — never copy REF-A numbers) · Owner: Security/BSP**

## 1. Partition table (REF-B authoritative — flash tooling reads this file)

```
boot_a / boot_b ............ 64 MiB  (Image.gz + ramdisk, hash footer)
vendor_boot_a/b ............ 96 MiB  (larger vendor ramdisk: Mali firmware staging — measured, not guessed)
vbmeta_a / vbmeta_b ........  8 MiB
dtbo_a / dtbo_b ............ 16 MiB  (bigger overlay set: panel variants ×2 at launch)
super ...................... <REF-B size per flashmap.json — fill from stock GPT dump, not REF-A>
host_a / host_b ............ 4 GiB   (Debian erofs + Mali userspace — size delta vs REF-A recorded with reason)
misc .......................  4 MiB
persist / nvdata / nvram ... NEVER flashed (MTK NVRAM holds IMEI/MAC — backup ritual ch.02 §5 adapted: SP Flash-adjacent readback where fastboot can't reach, documented per unit)
userdata ................... remaining (LUKS2, same params as ch.08 §9 — crypto identical, sizes differ)
```

MTK-specific: preloader + `lk`/`little-kernel` region handling (our ABL-equivalent flow differs — `hw/<sku>/mtk-boot.md` documents download-agent auth requirements; unauthorized-DA bricks are the MTK classic, ritual prevents).

## 2. vbmeta/rollback/unlock (same policy spine as 08-A, REF-B values)

Flags (`0` dev / `2` release), rollback monotonic per train (independent counter from REF-A — cross-SKU index comparison meaningless, enforced by tooling reading the right file), unlock→wipe + orange warning, relock only on own signed images (quarterly sacrificial drill, same as 08-A §4). Yellow custom-key path identical (community ports unblocked).

## 3. NVRAM/MAC discipline (the MTK-specific section REF-A doesn't need)

Wi-Fi/BT MACs + IMEI live in NVRAM — factory script verifies post-flash that MACs equal pre-flash backup (diff check automated in `flashall.sh --verify-nv`; mismatch = halt + restore procedure, never ship a unit with zeroed MACs). MAC-zero incident = P0 process bug (not "reflash and move on" — the ritual failed, fix the ritual).

## Verification

- [ ] `flashmap.json` from stock GPT (not REF-A copy); NVRAM backup/restore drill green; MAC-verify in flash path.
