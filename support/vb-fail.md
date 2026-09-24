# vb-fail.md — verified-boot failure triage flow (ch.08 §27 support playbook)
**Owner: Support + Security · Phase: 3 — roleplayed per launch list; wording matches security/vb-screens.md verbatim**

## Step 0 — collect, never ask for secrets

Ask for the **Code** (VB-R1 corruption / VB-R2 rollback) + QR digest. Never ask for PIN/PUK/passwords — the screen footer already says "Support will never ask for your PIN".

## VB-R1 (corruption — "Software check failed")

1. Guide user through `[Try again]` once → slot-fallback (screen shows "attempt 2 of 2").
2. Still failing → re-flash canonical release: verify from transparency repo (hash + `avbtool` + rollback index) before install.
3. Re-bless data per ch.05 §12 tolerance; user data stays encrypted throughout (screen said so; keep it true).
4. Unresolved R1 ×2 → RMA-quarantine with wipe-verify discipline — a half-verified device never ships back as "clean".

## VB-R2 (rollback — "Outdated software blocked")

1. Update-only path: explain in one paragraph why the older image is refused (downgrade-attack protection — no crypto lecture).
2. There is no "boot anyway" — do not offer one; the absence of the button is the control.
3. If the newest update also refuses, escalate as P1 (rollback index mismatch = OTA-train bug, not user error).

## Records

Every case files `security/vb-fail-<date>.md`: code, digest prefix, slot, outcome. Trend input to the annual control-effectiveness review — rising R1 on one SKU is a flash-wear/firmware ticket, not user error.

Expected: user completes slot-fallback or canonical re-flash; case record exists before the ticket closes.

Fail action: any support step asking for PIN/PUK = process P0, retraining same week.
