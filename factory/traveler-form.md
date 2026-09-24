# Factory traveler form -- one per unit, flash to box (parent: factory-traveler-template.md).
# Technician fills in ink; supervisor signs the AVB-lock line. Scan redacted to
# factory/travelers/<serial>.pdf, retained 180 days. ASCII only.

Traveler ID: TRV-____-________-____ | SKU: ____ | Panel variant: ____ | eUICC Y/N: __
Operator: ____ | Station: ____ | Date/time UTC: ____ | MANIFEST.lock SHA: ____
Release tag: halide-v__ | Builder digest: sha256:__ | flashall.sh version: __
GPT backup: [ ] taken-now [ ] --i-have-backup (file ref: ____)

## Flash log refs
| Step | Command / check | Result | Log ref |
|---|---|---|---|
| GPT backup | flashall.sh --take-backup-now | OK/FAIL | logs/flash-____-gpt.bin.sha |
| Flash all | fastboot flashall per flashmap.json | OK/FAIL | logs/build-____.json lines __ |
| Per-partition verify | fastboot getvar + avbtool info_image | flag=2, key=prod | avb-verify.txt Y/N |
| fastboot -w | typed SKU confirm ____ | done/skipped | initials __ |
| AVB lock | fastboot flashing lock, operator YES | locked/unlocked-dev | supervisor __ |
| LUKS2 first-boot | PIN >= 6 forced, argon2id | OK/FAIL | luksDump slots=1 |

vbmeta rollback_index: ____ (must exceed previous release)
ro.boot.verifiedbootstate: ____ (green = shippable; orange/yellow = dev-only + warning sticker)

## MAC and identity
Wi-Fi MAC: ____ | BT MAC: ____ | label match Y/N: __ | mac-range.txt line: __
Serial<->MAC map: factory/<sku>/serial-mac-____.csv line __
Sticker: SKU __ serial __ halide-v__ support-URL __ reg-marks __ MAClast4 __

## Smoke (all green before box; fail = red tag + quarantine + bug ID)
| Test | Expected | Actual |
|---|---|---|
| sys.boot_completed=1 <= 120 s container | yes | __ |
| Phosh + 1 Android app visible | yes | __ |
| Signal bars photo attached | match mmcli +-1 | __ |
| 1 MO call 60 s + 1 MT SMS loopback | pass | __ |
| Wi-Fi WPA2 + 1-min iperf | >= gate | __ Mbps |
| A/B slots both bootable | yes | __ |
| halide-log-collect dry-run | redacted bundle | __ |

Operator __ QA spot-check __ EDL use (who/when/why + loader hashes): ____
