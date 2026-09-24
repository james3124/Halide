# custodians.md — signing-ceremony custodians (ch.08 §8, ch.09 §15 normative)
**Owner: Security · Phase: release signing — the room where trust lives (ch.08 §19)**

## Roles (2-of-3 quorum per ceremony — never one person, never all-remote)

| Custodian | Role | Duty | Backup |
|---|---|---|---|
| C1 | Release engineer | drives offline signer, reads hashes.txt aloud | C2 |
| C2 | Security lead | verifies SHAs + key fingerprints before sign | C3 |
| C3 | Arch (rotating) | co-signs + attests ceremony log (anomalies-or-none line) | C1 |

## Ceremony (quarterly or per release; log started before USB inserted)

1. Verify builder `hashes.txt` SHAs on the offline machine (mismatch = halt, no "re-sign anyway").
2. Sign boot/vendor_boot/super/vbmeta + OTA payload with the per-SKU release key.
3. Write `signatures.json` (artifact, signer id, timestamp, rollback index).
4. Append transparency entry to the append-only `halide-transparency` repo.
5. Publish pubs if rotated (dual-sign: N ships old+new, N+1 new-only, N+2 drops old).

## HSM / offline machine

- Root key: HSM or air-gapped USB, RSA-4096 (see `signer-spec.md`); never networked, never in CI.
- Two custodians physically present for every private-key operation; session logged and committed.
- SIGN-X sticks travel builder→signer→publisher only — a SIGN-X stick on a factory station is a process fail (ch.09 §28).
- Lost custodian: quorum falls back to written deputy named here + Arch co-sign; roster reviewed quarterly (stale roster = same STALE discipline as ch.01).

Expected: ceremony log shows two custodian initials + hashes-verified line + anomalies-or-none.

Fail action: any missing line = unsigned, repeat ceremony; no verbal "it was fine".
