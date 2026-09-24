# Fleet Management Guide
**Parent: 01-vision-requirements-personas.md (P3 Enterprise/NGO) / 09-build-ota-factory-ci.md**

## 1. Scope and P3 contract
Fleets of 50–500 devices need reproducible images, staged OTA, remote wipe with attestation, and auditor-ready artifacts from the public release page alone. This guide is the P3 acceptance path: enroll 50, stage an OTA, wipe one with proof. systemd-as-PID1 throughout; AVB green + LUKS2 mandatory on fleet builds; single-stack networking (NetworkManager authoritative, Android netd shimmed) so fleet VPN policy actually holds.
Non-goals v1: MDM agent inside Android container as device owner (host is owner); eSIM bulk provisioning (Phase-4).

## 2. Enrollment
1. Build or fetch release: tag `halide-vX.Y.Z+<sku>` + `MANIFEST.lock` + `SBOM.spdx.json` + `avbtool info` dumps archived.
2. Per-device provision: flash per factory runbook, force PIN ≥6 + auto-encrypt (LUKS2 AES-256-XTS Argon2id), record serial↔pubkey in `fleet/<org>/inventory.csv` (fields: serial, SKU, panel variant, Wi-Fi MAC last-4, release, enrollment date, custodian).
3. Enroll keys: install org OTA pub + WireGuard/VPN profile via USB provisioning stick (`fleet-enroll --org <id> --usb /mnt/stick`); verify `halide-release` + container `build.prop halide.version` match or first-boot refuses.
4. Permission baseline: single-consent mapping committed (`fleet/<org>/permissions.json`); Android `READ_SMS` never silently grants host address-book — explicit dual approval logged.
5. Redaction: inventory holds no IMSI/IMEI/ICCID; support exports via `halide-log-collect --redact`.

## 3. Staged groups and OTA policy
Groups: `canary` (2%), `pilot` (10%), `fleet` (rest). Rollout 1%→10%→50%→100% with 48 h bake; auto-halt at >2% rollback (update_engine health gate: container `boot_completed` + radio registered ≤5 min or rollback + `halide-ota-report`).
| Group | Deadline | Required battery | Action on miss |
|---|---|---|---|
| canary | 48 h | ≥30% or charger | freeze, pull 5 redacted reports |
| pilot | 7 d | ≥30% | bisect MANIFEST delta, hotfix train |
| fleet | 30 d security deadline | ≥30% | escalate to Arch, N-1 backport |
Delta vs full sizes published so metered-link sites can plan; sideload path carries identical verify+health gates.

## 4. Per-serial health
Nightly `fleet-health <org>`: per-serial rows (last check-in, release, AVB state, patch age, battery cycles, modem crash count, rollback count). Thresholds: patch age >45 d amber, >60 d red (blocks release per ch.08); modem crashes >1/week fleet-wide = P0 baseband sprint. Dashboard source: opt-in redacted telemetry + on-LAN `halide-fleet-poll` (no silent cloud). Stale >14 d flagged `MISSING` (lost/stolen workflow §5).

## 5. Wipe, lock, and attestation collection
Remote wipe: signed wipe command over fleet channel; device crypto-erases LUKS data keyslot + `blkdiscard` userdata + new UUIDs, writes `WIPE <sku> <ts> <operator-confirm-id>` to recovery log. Verification: canary file `CANARY-<rand>` absent post-wipe via `hexdump` sample; wipe attestation line collected to `fleet/<org>/wipes/<serial>.log` and shown to admin within 24 h. Lost mode: lock + charging-only USB + `ro.adb.secure=1` asserted; recovery never mounts userdata decrypted without auth. Enterprise may set wipe-at-N wrong-PIN policy (default offer at 30).

## 6. Audit pack and offboarding
Auditor gets without asking engineering: SBOM, CVE dispositions (`security/CVE-*` records), build hashes, transparency-log entry, carrier blessing sheet. Offboard: de-enroll key, rotate org VPN creds, crypto-erase + reissue traveler for reuse or destruction cert.

## Verification
- [ ] 50-device enrollment completes from release page artifacts alone (hashes verify).
- [ ] Staged OTA canary→pilot→fleet with auto-halt demonstrated on a forced-bad slot.
- [ ] Per-serial health shows AVB/patch/battery/modem columns with amber/red rules firing.
- [ ] Remote wipe on one unit returns signed attestation line + canary-absent proof ≤24 h.
- [ ] Inventory and bundles contain no IMSI/IMEI; permission baseline shows no silent inheritance.
