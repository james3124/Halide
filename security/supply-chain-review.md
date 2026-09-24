# supply-chain-review.md — blob provenance & dependency review policy (ch.08 §23 STRIDE-per-input; ch.09 §13 digest pinning)
**Owner: Security + Release · Phase: all — every input is untrusted until pinned and verified**

## Policy rows per dependency class

| Class | Provenance required | Verification | Failure action |
|---|---|---|---|
| Vendor blobs (GPU/modem/touch FW) | blob SHA + MANIFEST range in `hybrid/manifests/MANIFEST.lock` | SHA verified at fetch-then-verify; hash-mismatch = freeze (ch.09 §13) | quarantine blob, file ticket, no swap-by-vibes |
| Builder image | digest pinned in ci/Dockerfile + station images | digest diff at job start | refuse job |
| Debian packages | packages.host curated + lockfile | `dpkg -l` digest recorded per builder | builder-drift fix before compile |
| AOSP mirror | repo manifests pinned; mirror untrusted by design (ch.09 §19) | verify anyway (SHA per project) | re-sync from canonical |
| OTA payload | signed by ceremony key; rollback index monotonic | avbtool verify + SHA256.signed.txt | halt install |
| Factory station inputs | flashmap + images SHA-verified post-fetch (ch.09 §28) | station-selftest | refuse to flash |

## Rules

1. No blob ships without SHA + manifest range — "driver version 1.2" bare claims are blocklisted (docs-style-guide §2).
2. Third-party deps get a STRIDE-per-input row (spoofing/tampering per input, not vibes).
3. Compiler/toolchain bumps = toolchain-bump procedure with proof (ch.03 §32); never drive-by.
4. Factory tooling honesty: over-provisioning residual attested by blkdiscard+crypto-erase composition argument, stated in audit report (ch.08 §28).

Expected: SBOM (hybrid/sbom/SBOM.spdx.json) diff attached for image-affecting MRs; provenance rows green before release train.

Fail action: unpinned input found = block MR, provenance added or dep removed.
