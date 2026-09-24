# kdf-drill-<date>.md TEMPLATE -- annual KDF rotation drill (ch.08 S32 + S19 week)
# Copy to security/kdf-drill-<YYYY-MM-DD>.md. Drill uses real re-encrypt on a
# sacrificial unit (old header -> re-encrypt -> new header), never passwords alone.
# Owner: Security

| Field | Value |
|---|---|
| Date | TODO |
| SKU / unit | TODO (sacrificial unit label) |
| Registry SHA before/after | TODO / TODO (read aloud per ceremony, S32) |
| Re-encrypt duration | TODO (battery >= 50% + charger + header backup SHA logged pre/post) |
| Header rotated (SHA differs) | TODO (PASS/FAIL) |
| Old wrapped key fails | TODO (attempt-and-fail logged, PASS/FAIL) |
| Rollback-path demo | TODO (failed re-encrypt rolls back to old header, never strands) |
| Unlock p50/p95 after | TODO ms / TODO ms (within SLO per unlock-<sku>.md) |
| Custodians (2 initials) | TODO + TODO |
| Transparency id | TODO |
| Anomalies-or-none | TODO (required line) |

Failed drill or SLO miss = P0 (erase/unlock is the last promise, S21/S32).
