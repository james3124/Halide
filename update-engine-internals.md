# update_engine Internals — Payload, Health Gates & Rollback State Machine
**Parent: ch.09 §§4,9 · Owner: Release · Payload format: update_engine-compatible (brillo heritage)**

## 1. Payload anatomy (byte-level honesty — corrupted payloads brick modems' cousins)

`payload.zip`: `payload.bin` (block ops: `REPLACE`, `REPLACE_BZ`, `ZERO`, `SOURCE_COPY` for deltas + `BROTLI_BSDIFF` where economical) + `payload_properties.txt` (`FILE_HASH`, `FILE_SIZE`, `METADATA_HASH`, `METADATA_SIZE`) + `metadata.json` (HALIDE extension: from/to versions, slot requirement, battery ≥30% + charger-or-override flag, changelog URL, `security_deadline` for forced-update UX). Full vs delta decision (ch.09 §9 100M cap) recorded per release with sizes both ways (delta smaller but riskier to generate — corrupt-delta history in other projects justifies the cap).

Signing: whole-`payload.bin` RSA4096 + per-partition hashes inside manifest protobuf (two layers — outer key compromise doesn't silently alter a partition). Verification order on device: key → outer hash → rollback-index > current → per-partition hashes DURING write (streaming verify, not post-hoc — a failed partition aborts before slot-mark, §3).

## 2. Write path (inactive slot only — active slot is never written, ever)

`update_engine` → `boot_control HAL` (slot metadata in `misc`, ch.08-A policy) → stream ops to inactive `boot/vendor_boot/super/host` → fsync per partition → `mark-boot-successful=false` + `tries-remaining=7` on new slot → set staged-slot → reboot. Power-loss at any point: staged-but-unbooted slot boots max 7 tries then auto-falls-back (bootloader `tries-remaining` logic — tested by yanking power mid-first-boot-of-new-slot on sacrificial unit quarterly; the test is scheduled, not aspirational).

## 3. Health-gate state machine (post-reboot commit logic — the actual rollback safety)

```
STAGED --reboot--> VERIFYING --[systemd running ≤90s]--> HOST_OK
HOST_OK --[boot_completed ≤5min]--> ANDROID_OK --[MM registered + 1 SMS loopback]--> RADIO_OK
RADIO_OK --[user present 10min OR 24h auto]--> COMMITTED (mark-boot-successful)
any gate timeout/fail --> ROLLBACK (bootloader falls back, old slot boots, halide-ota-report filed)
```

Timeouts committed per SKU (modem-slow SKUs get longer RADIO window with reason — blanket 5-min everywhere fails honest SKUs). `halide-ota-report` (redacted, ch.09 §9): versions, per-gate timestamps, failing gate, slot states — auto-uploaded on Wi-Fi with consent, always stored locally for support reads (support script §2 asks for it by name).

## 4. Forced-update & deadline UX (security updates without bricking trust)

`security_deadline` in metadata (CVE-driven, ch.08 §11 SLA): pre-deadline = polite daily card; deadline-week = persistent-but-dismissible banner; post-deadline = update-required-for-radio-reattach? NO — never degrade the phone as coercion (written here so growth-pressure can't invent it later). Post-deadline = fullscreen-explained prompt on unlock with one-tap install + "remind tonight" (friction honest, function intact). Enterprise P3 can set hard deadline via policy (their devices, their rule — consumer builds never).

## 5. Delta-generation QA (deltas are diffs — diffs lie)

Delta built host-side from exact from/to images (MANIFEST-locked SHAs — delta from anything else refused at verify). Delta test matrix per release: full-path (N-1→N full), delta-path (N-1→N delta), skip-path (N-2→N full, deltas only support adjacent), interrupted-download resume (kill at 30/70/95% → resume → verify green). Delta that fails any path falls back to full automatically with reason logged (user sees "Update package refreshed", not an error).

## Verification

- [ ] Staged-write + power-yank + double-fail rollback all demonstrated on hardware; report readable by support script.
