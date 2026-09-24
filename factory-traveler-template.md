# Factory Traveler Template
**Parent: 09-build-ota-factory-ci.md / factory/<sku>/flashall.sh**

## 1. Purpose and handling
One paper (or printed PDF) travels with each unit from flash to box. It links flash-log refs, MAC verification, smoke results, and sticker data so RMA can trace any unit without guessing. systemd-as-PID1 and AVB green are verified here, not assumed from CI. Technician fills in ink; supervisor signs AVB-lock line. Retain scan 180 days with build artifacts.
Rules: IMSI/IMEI/ICCID never pre-printed in bulk; hand-written only where needed and redacted in scans via `halide-log-collect --redact`.

## 2. Header fields
```
Traveler ID: TRV-<sku>-<yyyy>-<seq> | SKU: ____ | Panel variant: ____ | eUICC present Y/N: __
Operator: ____ | Station: ____ | Date/time UTC: ____ | MANIFEST.lock SHA: ____
Release tag: halide-v__ | Builder digest: sha256:__ | flashall.sh version: __
GPT backup: [ ] taken-now [ ] --i-have-backup (file ref: ____)
```

## 3. Flash log refs
| Step | Command / check | Result | Log ref |
|---|---|---|---|
| GPT backup | `flashall.sh --take-backup-now` | OK/FAIL | `logs/flash-<serial>-gpt.bin.sha` |
| Flash all | `fastboot flashall` per flashmap.json | OK/FAIL | `logs/build-<sku>-<ts>.json` lines __ |
| Per-partition verify | `fastboot getvar` + `avbtool info_image` | flag=2, key=prod | `avb-verify.txt` attached Y/N |
| `fastboot -w` | typed SKU confirm `____` | done/skipped | operator initials __ |
| AVB lock | `fastboot flashing lock` operator YES | locked/unlocked-dev | supervisor sign __ |
| LUKS2 first-boot | PIN ≥6 forced, `luksDump` argon2id | OK/FAIL | `luksDump.txt` slot count=1 |
Record `vbmeta` rollback_index (must be > previous release) and `ro.boot.verifiedbootstate` (must read `green` for shippable; orange/yellow = dev-only with warning sticker).

## 4. MAC and identity verify
Record Wi-Fi MAC, BT MAC, Ethernet (if dock) from `ip link` + Settings → About. Check against label + `hw/<sku>/mac-range.txt` allocation; duplicates halt the line. Procedure: scan barcode → compare `wl:`/`bt:` → tick. Spoof/override forbidden on production images (`CONFIG` check: no `macrandomize` override active). Serial ↔ MAC mapping file ref: `factory/<sku>/serial-mac-<date>.csv` line __. Sticker data fields: SKU, serial, `halide-v` version, support URL, regulatory marks, MAC last-4 (full MAC inside box only).

## 5. Smoke results
Cold boot → lock screen ≤45 s (time: __s). Checklist, all must pass before box:
| Test | Expected | Actual |
|---|---|---|
| `sys.boot_completed=1` ≤120 s container | yes | __ |
| Phosh + 1 Android app visible | yes | __ |
| Signal bars photo attached | bars match `mmcli` ±1 | __ |
| 1 MO call 60 s + 1 MT SMS loopback | pass | __ |
| Wi-Fi WPA2 connect + 1-min iperf | ≥gate | __ Mbps |
| A/B slots both bootable (`bootctl status`) | yes | __ |
| Recovery: `halide-log-collect` dry-run | redacted bundle | __ |
Fail = red tag + quarantine shelf + bug ID filed before re-flash. Fresh-eyes rule: runbook must be usable by a non-engineer quarterly or the runbook is wrong.

## 6. Sign-off and filing
Operator sign __, QA spot-check initials __, scan to `factory/travelers/<serial>.pdf` (redacted). Quarantine units file traveler in `quarantine/` with bug link. EDL unbrick use logged (who/when/why + signed loader hashes) on traveler back.

## Verification
- [ ] Every shipped unit has a traveler scan linked to MANIFEST.lock + avb verify output.
- [ ] AVB state green asserted via `avbtool info_image` (flag 2, prod key, monotonic rollback).
- [ ] MACs verified against allocation, no duplicates; sticker fields complete.
- [ ] Smoke table 100% green or unit quarantined with bug ID.
- [ ] Scans redacted (no IMSI/IMEI in retained PDFs); retention 180 days confirmed.
