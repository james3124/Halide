# vb-screens.md — verified boot state screens (ch.08 §27 exact wording; support trained verbatim)
**Owner: Security + UI · Phase: 3 — wording drift between screen/docs/support is a P1 trust bug**
State vocabulary driven by `ro.boot.verifiedbootstate`: GREEN (locked+verified, no warning), ORANGE (unlocked bootloader), RED (failure: corruption VB-R1 / rollback VB-R2).

## GREEN

No warning. About shows "Verified boot: on".

## ORANGE (5s dwell; power-button skips; unskippable-by-default flag)

- Title: `Unlocked bootloader`
- Body: `This device doesn't verify its software before starting. Only use test builds here — banking, work, and personal accounts are at risk.`
- Buttons: `[Continue once] [Open guide]` (guide = offline HTML: re-lock + data-loss warning; nightly expiry date shown where applicable).

## RED — corruption (VB-R1, dm-verity boot-critical)

- Title: `Software check failed`
- Body: `Your device found damaged or modified system software and stopped to protect your data. Code VB-R1. Your photos/messages are still encrypted.`
- Buttons: `[Try again] [Factory reset (erases)] [Support options]` — Try-again once then slot-fallback (attempt 2 of 2 shown); Factory-reset routes to wipe-verify flow (never one-tap from a panic screen); Support-options shows QR of redacted vbmeta digest + rollback index + slot (no IMEI/IMSI).

## RED — rollback (VB-R2)

- Title: `Outdated software blocked`
- Body: `This version was blocked by rollback protection (Code VB-R2). Install the newest update instead of this older one.`
- Buttons: `[Install latest] [Support options]` — **no "boot anyway"**: the absence of the button is the control.

## Rules

- Footer on every failure screen: `Support will never ask for your PIN` (social-engineering inoculation printed where the victim looks).
- Eng `VERITY OFF` watermark never appears on release RED/ORANGE screens (watermark is eng-only; release screens carry codes, not watermarks).
- Translations: top-12 languages; quarterly sacrificial bit-flip drill asserts screen + code + QR shape.

Expected: quarterly drills show RED-corruption + RED-rollback + ORANGE copy matching this file exactly.

Fail action: wording drift found = P1 trust bug, fixed same cycle.
