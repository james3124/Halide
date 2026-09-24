# keys/ceremonies/README.md -- signing-ceremony log index (ch.08 S8, S19, S32)
# Owner: Security * Two custodians per ceremony; log started BEFORE the USB is
# inserted; every log carries hashes-verified line + anomalies-or-none line.
# Missing line = unsigned, repeat ceremony (no verbal "it was fine").

Log naming: ceremonies/<YYYY-MM-DD>-<release-or-kdf-delta>.md (release signing)
and ceremonies/kdf-<YYYY-MM-DD>.md (KDF rotation deltas: new kdf-registry.json
SHA read aloud + transparency id + LUKS header SHAs before/after, S32).

Template per ceremony (copy into the dated file):

| Field | Value |
|---|---|
| Date / release | TODO |
| Custodians (2 initials) | TODO + TODO |
| hashes.txt SHAs verified | TODO (mismatch = halt, no re-sign-anyway) |
| Artifacts signed | TODO (boot / vendor_boot / super / vbmeta / OTA payload) |
| signatures.json ref | TODO (artifact, signer id, timestamp, rollback index) |
| Transparency id | TODO (append-only halide-transparency repo) |
| Pubs published (if rotated) | TODO (dual-sign N/N+1/N+2 stage) |
| Anomalies-or-none | TODO (required line) |

No ceremonies logged yet (TODO until first signing -- TODO is honest).
Key-generation ceremonies (once per key, witnessed, HWRNG-seeded RSA4096 on the
signer, never online) filed here with the same schema + witness signatures.
