# SMSC / MMSC Detail — Routing, Retries, Delivery Reports & MMS Adaptation
**Parent: ch.07 §§5,13 · Owner: Telephony · Test oracle: stock phone + carrier spec where obtainable**

## 1. SMSC path (why "sent" ≠ "delivered" — the state machine users deserve)

Outbound: app/Chats → MM `--messaging-create-sms` (number normalized E.164 via libphonenumber with country from MCC — normalization logged, wrong-country sends are P0) → SMSC submit → `SUBMITTED` → network `DELIVERED` report (where carrier sends them — some don't; per-carrier `delivery_reports: full/partial/none` in `profile.json`, ch.07 §11 schema extended) → UI state transitions PENDING→SENT→DELIVERED (or PENDING→SENT→UNKNOWN where carrier silent — UI shows "sent" without fake checkmark-double; the double-check requires a report, enforced in UI review). Retry: no-ack 60s → retry ×2 with backoff (2min, 10min) → fail with `SMSC_TIMEOUT` + user-facing "not delivered" (never infinite-pending — pending-forever is the #1 SMS trust killer).

SMSC address: auto from SIM (`EF_SMS`/`EF_SMSP`, verified via `mmcli -i` read) with manual override in Settings (roaming-SIM edge: some carriers need explicit SMSC when roaming — override path tested with roaming fixture, not discovered by travelers). Concatenation: UDH 6-byte ref, 153-char segments, reassembly 60s window + PDU-hash dedupe (ch.07 §13); segment-loss (missing middle) → "incomplete message" placeholder with sender+time (not silent drop, not garbled glue).

## 2. MMS adaptation engine (MMSC per carrier profile, transcode honestly)

`mmsd-tng` send path: compose (MIME: SMIL + parts) → data-bearer check (MMS APN attached or attach-now with progress — sending MMS on wrong APN fails opaquely; our UI names the APN in the error) → POST to MMSC → `M-Send.conf` → delivery. Receive: WAP-push SMS (port 2948) intercepted by MM → auto-fetch on Wi-Fi/unmetered-data, prompt on metered (user setting, default per carrier profile `mms_autofetch_metered:false`) → parts decoded → group-thread merge (same recipients±1 normalized = same thread; merge mistakes logged with thread IDs for support, ch.10-adjacent support script names the export).

Transcode policy: images > carrier limit (usually 300KB–1MB, per-profile `mms_max_bytes`) downscaled client-side with quality note shown ("resized to 600KB for <carrier>") — silent full-res-fail vs surprise-resize both bad; chosen: resize + note. Video MMS: 1 15s clip attempt per carrier at bring-up, result recorded (most fail — recorded-fail beats assumed-fail).

## 3. OTP special handling (the P1 banking story depends on this slice)

`SMS_RETRIEVER`-compatible broadcast (bridges/permission §5 OTP note): allowlisted packages get sender+body hash-routed within 5s of receipt (timer test with 2 real flows per release, ch.07 verification). OTP auto-suggest in host keyboard (Phosh path) mirrors same content (one OTP system, two surfaces). OTP SMS never included in backup exports by default (security note shown once — stolen-backup OTP replay is a real attack; exclusion documented in runbook-firstboot backup screen).

## Verification

- [ ] E.164 normalization + retry/timeout + dedupe proven with fixtures; per-carrier delivery-report capability recorded; MMS 3×3 (contacts×directions) + group-thread sanity; OTP 2-flow timer test green.
