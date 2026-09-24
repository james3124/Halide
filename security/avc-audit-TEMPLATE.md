# avc-audit-<quarter>.md TEMPLATE -- quarterly neverallow audit (ch.08 S31)
# Copy to security/avc-audit-<YYYY>-Q<N>.md. Inputs: 90d audit.log (dogfood
# opt-in only) + nightly fuzz runs + soak units. Feeds the S24-family review
# (no audit file = family marked EVIDENCE-LATE per S30). Owner: Security + QA.

| Field | Value |
|---|---|
| Quarter | TODO |
| Baseline ref | TODO (logs/<sku>-selinux-baseline.txt SHA) |
| New denials (count) | TODO |
| Dispositions (ALLOW / MITIGATED / PRODUCT-BUG) | TODO n / TODO n / TODO n |
| Expired rules renewed-or-removed | TODO (list; expired-kept fails the build) |
| Fuzz coverage trend link | TODO |
| Artifact hashes (S30 pinning) | TODO |

Stale-bin rule: dispositions older than their S15 clock without change escalate
to Arch via bot-filed ESCALATE issue (clocks without escalation are wishes).
