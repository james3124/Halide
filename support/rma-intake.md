# rma-intake.md — RMA intake checklist (warranty-rma-ops §2; one per unit)
**Owner: Support + QA · Phase: retail/dogfood — no signature = no repair beyond non-destructive triage**

## Intake form (fill before ticket opens)

| Field | Value |
|---|---|
| Unit label + serial (last-4 beyond this; full serials in sealed inventory) | |
| SKU | REF-A / REF-B |
| Shipped version + current version | MANIFEST.lock SHAs where known |
| Symptom (one line) + first-seen date/build | |
| Repro tried: reboot / container restart / sideload-current-OTA / factory-reset-consent | y/n each |
| Accessory set returned (cable/charger) — SIMs never returned | privacy rule stated on form |
| Data-backup consent + wipe authorization signature | no signature = non-destructive triage only |

## On receipt

1. Photo-in: unit + seals + traveler page.
2. Power-on smoke: `boot_completed` y/n; `avbtool info` rollback + key state recorded — **testkey on a shipped unit escalates to incident, not warranty repair** (routed to engineering pool).
3. Open ticket in `support/rma-log.csv` (id, date-in, SKU, symptom class, triage owner, SLA clock start).

## SLA rules

- Triage verdict ≤3 business days; repair/replace ≤10 business days.
- Clock pauses only on documented customer-wait with timestamps — pause-without-note counts against MTTR.
- Unlock policy: unlock voids software-brick coverage past one good-faith EDL unbrick; relock to release keys + clean flash restores full warranty (verified by `avbtool`).

Expected: every open ticket has intake form + photo-in + SLA clock with documented pauses.

Fail action: missing wipe consent → device sits in quarantine, never wiped "to save time".
