# Field-issue intake template (field-issue-escalation S1-S2).
# Copy to support/FLD-<Y>-<NNNN>.md at first contact. No report lives in chat.
# Clocks start at first-contact timestamp. Redaction mandatory before upload.

ID: FLD-TODO (FLD-<Y>-<NNNN>)
First-contact-UTC: TODO
SKU + fingerprint + MANIFEST-range: TODO
Bundle: TODO (halide-logs-<sku>-<ver>-<ts>.tar.gz, redacted per redact-rules.conf)
Base-verified: TODO (halide-doctor --verify-base; UNVERIFIED-BASE = best-effort queue)
Repro-attempt-log: TODO (runbook-firstboot/recovery steps tried)

## Ladder
| Rung | Owner | Clock | Status |
|---|---|---|---|
| L1 Support | Support | acknowledge 24h; resolve or escalate <=48h with bundle | TODO |
| L2 QA repro | QA | acknowledge 48h; repro yes/no + severity within 5 days (exact-SKU lab unit) | TODO |
| L3 Engineering | Platform/BSP owner | fix-or-mitigation per severity clock; MR refs FLD id; regression test committed | TODO |
| L4 Post-resolution | Support + QA | follow-up survey + close <=14 days post-ship | TODO |

## Severity (one language with security)
S0 fleet-down/safety (P0-CRIT): ack 4h, mitigation <=7d, hotfix same-week, halt armed
S1 broken daily-driver (P1-HIGH): ack 48h, fix <=30d (monthly train)
S2 degraded/workaround (P2-MED): monthly train, 90-day cap
Auto-upgrade to S0 on active-exploitation/safety evidence (telemetry/PoC/anomaly).
Single-stack networking failure defaults S1 minimum; permission split-brain in
wild defaults S1, S0 if exploited.
Incomplete bundles bounce once with checklist; second bounce escalates to
Support lead (process failure, not user failure).
