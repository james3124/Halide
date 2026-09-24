# keys/REF-B/KEYS.md -- REF-B key inventory (appendix-08B S2, ch.08 S8)
# Pubs + metadata ONLY (never private in git -- scanner enforced).
# Rollback counter is INDEPENDENT from REF-A (cross-SKU comparison meaningless).
# Owner: Security * Rotation: dual-sign N / N+1 / N+2 (same rhythm as REF-A).

| Key | Id | Fingerprint (SHA-256) | Algorithm | Created | Rotation due | Custodians |
|---|---|---|---|---|---|---|
| Release AVB (REF-B) | TODO | TODO (read aloud at ceremony) | RSA4096 (avbtool SHA256_RSA4096) | TODO | TODO | C1+C2 (custodians.md) |
| OTA payload (REF-B) | TODO | TODO | EC-P256 | TODO | TODO (independent per SKU) | C1+C2 |
| Previous (N-1, dual-sign) | TODO | TODO | -- | -- | drop at N+2 | -- |
| Emergency root | TODO | TODO (shared root fingerprint, purpose-limited) | RSA4096 | TODO | decade or incident | any-2-of-3 |

MTK note (appendix-08B): download-agent auth requirements live in hw/<sku>/mtk-boot.md;
NVRAM backup/restore ritual + MAC-verify in flash path (mismatch = halt, P0 process bug).
