# Appendix 08-A — REF-A AVB Policy, Partitions & Rollback
**Parent: ch.03 §6, ch.08 §2 · Owner: Security/BSP · Per-SKU (this file: REF-A SDM845)**

## 1. Partition table (authoritative for REF-A; flash tooling reads this, not guesses)

```
boot_a / boot_b ............ 64 MiB  (Image.gz + ramdisk, hash footer)
vendor_boot_a/b ............ 64 MiB  (vendor ramdisk + DTB overlays)
vbmeta_a / vbmeta_b ........  8 MiB  (chain: boot+vendor_boot+super descriptors)
dtbo_a / dtbo_b ............  8 MiB  (panel/touch overlays per variant)
super ...................... 9 GiB  (system+system_ext+product+vendor logicals)
host_a / host_b ............ 3.5 GiB (Debian erofs; A/B with super slot lockstep)
misc .......................  4 MiB  (slot metadata + wipe attestation line)
persist .................... 32 MiB  (NEVER flashed by factory script — calibration)
efs/modemst1/modemst2 ...... stock sizes (NEVER touched — backup ritual ch.02 §5)
userdata ................... remaining (LUKS2, crypto-erase-able)
```

Slot lockstep: `super` slot X always pairs `host` slot X (mismatched pairs refused at boot with banner — ch.09 §8 version check). `flashmap.json` encodes these sizes; `flashall.sh` validates every image ≤ partition before flashing (ch.03 §18).

## 2. vbmeta descriptors & flags

`vbmeta` includes: hash descriptors (boot, vendor_boot), hashtree descriptors (super logicals, dm-verity), kernel-cmdline descriptor (`androidboot.verifiedbootstate`, `root_hash` for host verity), rollback-index descriptors per slot. Dev builds `--flag 0` (orange); dogfood+release `--flag 2` (green enforcing). `--flag 1` (yellow, custom key) used for community ports signing their own keys (documented path — ports aren't blocked on our HSM).

## 3. Rollback index policy

Monotonic per release train: monthly minor bumps index by 1; hotfix reuses index (same-month, no downgrade path created); major bumps by 10 (room for hotfixes). Quarterly rollback test (ch.10 §7 `ota-rollback-test.sh` + manual old-image flash → must refuse with `ROLLBACK_PROTECTION` event in pstore + recovery message, never a silent old-boot). Index values published in release notes (auditable without our tooling: `avbtool info_image`).

## 4. Unlock/lock lifecycle

Unlock (dev): `fastboot flashing unlock` → mandatory wipe (userdata + Android data, persist/efs preserved) + orange-state warning shown every boot (pipeline draws the warning — no hiding). Relock (dogfood/release): only on our signed images with index ≥ current; failed relock (wrong key/old index) aborts with reason, never bricks (tested on sacrificial unit quarterly). Community-key relock (yellow) documented with their own ceremony (their keys, their responsibility — our runbook is a template, not a service).

## 5. Key inventory for REF-A

Release AVB key id + fingerprint, OTA key id, previous-key retention (N/N-1 per ch.08 §8 dual-sign), emergency root id (offline, purpose-limited). `keys/<sku>/KEYS.md` holds pubs + metadata; private material lives per ch.08 §8 (never here — scanner enforced).

## Verification

- [ ] `avbtool info_image` dumps for all slots archived per release; flags/keys/indexes match this file.
- [ ] Rollback-refusal demonstrated quarterly (log + recovery photo).
- [ ] Relock drill on sacrificial unit passes without brick.
