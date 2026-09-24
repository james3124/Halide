# researchers.md — security research contacts & disclosure clock (ch.08 §13/§18/§22)
**Owner: Security · Phase: all — 90-day disclosure default with teeth**

## Contact

- Channel: security@ (see SECURITY.md) — PGP required for first contact; reports over public channels are NOT embargo-eligible.
- Triage SLA: 48h acknowledgment including credit-preference capture (name / handle-only / anonymous).
- Severity rubric: RCE-as-root / verified-boot bypass / lockscreen bypass / modem-data leak tiers with response times (ch.08 §11).

## Disclosure clock (90 days, default)

| Event | Clock |
|---|---|
| report received | T+0 |
| triage response | ≤48h |
| fix verified (research build offered to reporter, §22) | target ≤60d |
| advisory + credit wall published (atomic, CREDITS.md) | T+90d default |

Extensions: only by written agreement, max +30d, reason recorded (ch.08 §13 — the clock has teeth: a missed clock is a retro item, not a shrug).

## Researcher-build policy (§22)

- Builds distributed for verified reporters; KDF/signing separation stated — no weakened lab KDFs (research measures the shipped cost).
- Research images carry `RESEARCH-UNCALIBRATED` timing tags; never leak into release channels.
- Testkey images never ship as warranty firmware (routed to engineering pool).

Expected: every accepted finding has an advisory + CREDITS.md entry at disclosure, or a dated agreement note.

Fail action: missed 48h triage = SLA-MISSED-apology note on the eventual entry.
