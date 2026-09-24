# signer-spec.md — key spec (ch.08 §8 hierarchy; CI fails on any PRIVATE KEY block in keys/)
**Owner: Security · Phase: all — pubs + metadata only in `keys/` (scanner-enforced)**

## Hierarchy

| Key | Algorithm | Format in tree | Rotation |
|---|---|---|---|
| offline root | RSA-4096 | none (HSM/air-gapped; fingerprint only) | decade or incident |
| per-product release key | RSA-4096 | none (offline signer; fingerprint in MANIFEST.lock keys-id) | per major release |
| per-SKU AVB key | EC-P256 (PKCS#11/HSM-backed) | `avb-<sku>.x509.pem` + `key-metadata.json` | independent per SKU |
| OTA payload key | EC-P256 | `ota-<sku>.x509.pem` + `key-metadata.json` | independent per SKU |

`key-metadata.json` per key: algorithm, creation date, rotation due, custodian initials. Private bytes never exist in git — `keys/` holds only `.x509.pem` pubs + metadata.

## AVB key types

- `avb-<sku>.pem` → vbmeta + boot/dtbo hash descriptors; rollback index monotonic per release train.
- eng builds: local **testkey** — dev only, never ship (`testkey-never-ships` rule: CI grep fails release artifacts signed by testkey; a retail unit arriving on testkey routes to lab as engineering-pool, not RMA, ch.11 warranty-rma-ops §unlock policy).
- `verify=off` / `--disable-verity` outside eng-orange is forbidden (`security/avb-policy.txt`).

## Verification a user can run

```
avbtool info_image --image vbmeta.img | grep -i key
# Expected: the per-SKU release public key id, flags=2 (release)
```

Fail action: unknown key id on a release image = incident, ch.08 §8 compromise runbook (revoke → emergency OTA signed by root → advisory from `security/ADVISORY-TEMPLATE.md`).
