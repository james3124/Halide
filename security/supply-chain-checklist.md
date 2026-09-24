# supply-chain-checklist.md -- supply-chain review checklist (ch.08 S23, supply-chain-review.md)
# Owner: Security + area lead * Re-review: quarterly (modem-fw/carrier), annually otherwise.
# Each row: class -> threats (S/T/R/I/D/E) -> control -> residual + review trigger.
# Every row has an owner + re-review date below (TODO = fill at intake).

| # | Dependency class | Key threats | Control (binding ref) | Residual / review trigger | Owner | Re-review |
|---|---|---|---|---|---|---|
| 1 | Modem-fw blobs | T trojaned image; E QMI RCE; R vendor denial | SHA + vendor-note archived; sacrificial-first + re-bless; QMI fuzz | closed fw, behavioral attestation only / advisory or stall-regression => P0 | TODO | TODO (quarterly) |
| 2 | Connectivity-check / probe endpoints | S portal spoof; I probe metadata; T DNS hijack | allowlisted URI + HTTPS; probe marked + logged (egress-allowlist.txt) | observer sees probe timing / cert change => hold + verify | TODO | TODO |
| 3 | MBPI + carrier APN pushes | T malicious APN reroute; R carrier repudiation | pin + staging, no auto-promote; authenticated-push-only | stale APN DoS / >5 fallback/month => DB review | TODO | TODO (quarterly) |
| 4 | Research-build recipients | I leaked build aids exploit dev; R watermark doxxing | per-recipient hash watermark (no PII); research-key separation; expiry | determined-actor extraction / leak => rotate + shorten expiry | TODO | TODO |
| 5 | Factory-station laptop + USB sticks | T infected station; E evil SIGN-X stick | pinned station image; scanned single-purpose sticks; verify-after-write | physical access = game over (stated) / hash mismatch => freeze | TODO | TODO |
| 6 | Transparency repo + mirrors | T mismatched mirror bytes; R history rewrite | append-only + force-push disabled; user verify (hash + avbtool + rollback) | user skips verify / mirror complaint => canonical-hash check 24h | TODO | TODO |
| 7 | HSM/signer media + Shamir shares | I share theft; D quorum unavailable | 2-of-3 split; sealed off-site backup; annual stand-in drill | coercion out of scope (stated) / ceremony delay >2w => risk-12 | TODO | TODO |
| 8 | Power meters / lab calibration | T miscalibrated meter fakes gate; R unlogged ambient | per-unit calibration.md + footnote lint; 3-run same-ambient rule | +/-5% meter lie (documented) / calibration age >1y => renew | TODO | TODO |

Unfired triggers are findings (supply-evid.md, S30 family 8).
