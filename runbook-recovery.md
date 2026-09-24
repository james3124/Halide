# Runbook — Recovery, Sideload, Factory Reset & Log Export
**Parent: ch.09 §5, ch.08 §9 · Recovery: minimal AOSP recovery + `halide-` extensions**

## 1. Recovery menu (exact order, exact wording — screenshots in `recovery/UI.md`)

```
Halide Recovery vX.Y
1. Reboot system now (+ slot: A/B shown, active marked *)
2. Apply update via ADB sideload (same verify+health gates as OTA, ch.09 §9)
3. Export diagnostic logs (redacted bundle only — auth required if userdata encrypted, §3)
4. Factory reset (crypto-erase + attestation, §4)
5. Switch active slot (shows versions both slots; switching to older warns ROLLBACK but allows with confirm — user owns the risk, informed)
6. Power off
```

No shell in release recovery (eng recovery has shell with `ro.adb.secure` still enforced — ch.08 §10). Menu navigable with volume+power only (touch may be dead when you need recovery — hardware-button path tested on both REF units).

## 2. Sideload (no network, same safety as OTA)

`adb sideload payload.zip` → verify (key + rollback-index + size vs flashmap) → write inactive slot → mark staged → reboot → health gate (ch.09 §9: systemd + boot_completed + MM registered ≤5 min) → commit or auto-rollback + `halide-ota-report`. Sideload of a payload failing verify aborts BEFORE writing (verify-then-write, never write-then-verify). Operator-visible progress per partition (%, not spinner — 9GiB super takes minutes; silence breeds cable-pulls).

## 3. Log export (auth-gated, redacted)

Encrypted userdata → require lockscreen PIN on recovery screen (rate-limited per ch.08 §9) before mounting; export = `halide-log-collect --redact` bundle (pstore + last journal + radio slice + versions — never full userdata image). Export target: USB-OTG stick (FAT32/exFAT) or ADB pull; on-screen SHA256 of bundle (user reads it to support over the phone — support-script in `support/LOG-SCRIPT.md`). Unauthenticated export allowed ONLY for unencrypted-boot-failure case (pstore + versions, no userdata mount — the distinction is enforced in code + tested by `tests/recovery-auth.sh`).

## 4. Factory reset (crypto-erase + attestation)

Two confirmations + typed SKU (ch.05 §12) → `cryptsetup erase` data keyslot → `blkdiscard` userdata → new UUIDs → wipe attestation line to `misc` (`WIPE <sku> <ts> <confirm-id>`, ch.08 §9) → reboot to first-boot (runbook-firstboot.md). Post-wipe canary check (ch.08 §9) runs on sacrificial units quarterly; attestation line readable in fastboot (`fastboot oem halide-wipe-status`) for enterprise RMA verification (P3 story, ch.01 §11).

## 5. Slot surgery (when OTA fails twice)

After 2 consecutive failed health-gates on a slot: recovery offers "Mark slot BAD and stay" (prevents boot-loop roulette) + "Copy current-good to staged repair" (re-flash path) — both one-tap, both logged. `bootctl` state dump (`is-marked-successful`, `tries-remaining`) shown in slot screen (no hidden slot state — hidden state is how bricks happen).

## Verification

- [ ] Button-only navigation of all 6 items on both REF units; sideload-bad-payload aborts pre-write; auth-gated export proven with/without PIN; wipe attestation readable via fastboot.
