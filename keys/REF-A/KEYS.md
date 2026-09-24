# keys/REF-A/KEYS.md -- REF-A key inventory (appendix-08A S5, ch.08 S8)
# Pubs + metadata ONLY. Private material lives on the offline signer per
# keys/signer-spec.md (CI fails on any private-key block -- leak-scan.sh).
# Owner: Security * Rotation: dual-sign N (old+new) / N+1 (new-only) / N+2 (drop old).

| Key | Id | Fingerprint (SHA-256) | Algorithm | Created | Rotation due | Custodians |
|---|---|---|---|---|---|---|
| Release AVB (REF-A) | TODO | TODO (read aloud at ceremony) | RSA4096 (avbtool SHA256_RSA4096) | TODO | TODO | C1+C2 (custodians.md) |
| OTA payload (REF-A) | TODO | TODO | EC-P256 | TODO | TODO (independent per SKU) | C1+C2 |
| Previous (N-1, dual-sign) | TODO | TODO | -- | -- | drop at N+2 | -- |
| Emergency root | TODO | TODO (fingerprint only; offline HSM) | RSA4096 | TODO | decade or incident | any-2-of-3 |

Rollback index train: monthly minor +1; hotfix reuses index; major +10
(appendix-08A S3). Index values published in release notes (avbtool-verifiable).
Unlock lifecycle: unlock => mandatory wipe + orange warning; relock only on own
signed images with index >= current (quarterly sacrificial drill).
