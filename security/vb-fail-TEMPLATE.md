# vb-fail-<date>.md TEMPLATE -- verified-boot failure case record (ch.08 S27)
# Copy to security/vb-fail-<YYYY-MM-DD>.md per case. No IMEI/IMSI/PIN ever.
# Owner: Security + Support

| Field | Value |
|---|---|
| Date | TODO (YYYY-MM-DD) |
| Code | TODO (VB-R1 corruption / VB-R2 rollback) |
| vbmeta digest prefix | TODO (first 16 hex chars from support QR) |
| Rollback index | TODO |
| Slot | TODO (a / b) |
| SKU | TODO (REF-A / REF-B) |
| Path taken | TODO (slot-fallback / re-flash canonical / update-only / RMA-quarantine) |
| Outcome | TODO (recovered / quarantined / escalated) |
| Transparency ref | TODO (canonical image hash + avbtool verify line, ch.09 S17) |
| Anomalies-or-none | TODO (required line -- never empty) |

Rules: R1 x2 unresolved => RMA-quarantine (half-verified device never ships back
as clean). Rising R1 on one SKU => flash-wear/firmware ticket, not user error
(trend input to the S24-family review).
