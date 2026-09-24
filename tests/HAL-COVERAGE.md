# HAL-COVERAGE — HAL interface × contract-test matrix (ch.04 HALs, ch.10 §26 coverage map)
Every HAL we ship has one contract test or is honestly `planned` with an owner.
Never claim CTS/VTS parity beyond tests/cts-allowlist.txt + tests/VTS-PINNED.txt.

| HAL | Contract test (hybrid/) | Status | Plan ref |
|---|---|---|---|
| audio | bridges/tests/audio_contract.sh + tests/audio-route.sh + tests/audio-loopback.sh + tests/audio-xrun.sh | pinned | ch.04 §3, ch.05 §29, ch.10 §21 |
| camera | bridges/tests/audio_contract.sh (shared socket registry) + tests/camera-burst.sh + tests/camera-flush.sh + VtsHalCameraProvider* | planned | ch.04 §4, ch.10 §21/§24 |
| sensors | tests/hal-contract.sh (registry gate) + VtsHalSensors* + VTS-PINNED.txt row | planned | ch.04 §6, ch.10 §2 |
| GNSS | tests/gnss-track.sh + tests/gnss-assert.py + tests/gnss-replay.sh | planned | ch.07 §? GNSS deepdive, ch.10 §21/§24 |
| RIL | bridges/tests/ril_contract.sh + tests/call-loop.sh + tests/sms-loop.sh + tests/ussd-flow.sh + tests/plmn-select.sh | pinned | ch.05 §9, ch.07 §1 |
| composer | tests/hal-contract.sh (composer.sock row) + tests/jank-measure.sh (frame_timeline) + nightly screenshot diff | planned | ch.06 §10, ch.10 §23 |
| keystore | tests/keystore-level.sh + CtsKeystoreTestCases (allowlist) | pinned | ch.05 §3, ch.08, ch.10 §2 |
| biometrics | none — watchlist, informational only (never gating) | planned | ch.10 §2, biometric-policy |

Rules (ch.10 §26 coverage lint applies):
- `pinned` = contract test exists, honors the 0/1/2 exit contract (ch.10 §7), and runs
  from `ci/jobs-mr.sh` or nightly; `planned` = named owner + plan ref, no ship claim.
- biometrics stays informational per ch.10 §2 — promotion to allowlist requires
  fixture + golden + owner (§26 graduation rule).
- Every row here must trace to a row in reqs/TRACEABILITY.csv (same MR rule, ch.01 §20).
