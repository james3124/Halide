# keymaster-gatekeeper.md -- keystore wiring notes (ch.08 S26, ch.04 HAL table)
# Owner: Security/Android * v1 posture: NO StrongBox claim, NO tamper-resistant
# keystore claim, NO payment-grade promise. tests/keystore-level.sh asserts the
# sepolicy side (NEVERALLOW present) + device attestation side.

## 1. security_level enum (owned by the Keystore HAL abstraction from day one)

Software < TEE < StrongBox. AOSP KeyMint tags pass through the bridge UNMAPPED --
no v1 code path assumes Software == TEE. Bridge schema `key_attest` carries
`security_level + attestation_chain[]`, populated truthfully while always-Software,
so Phase-4 issuers change values, never the wire format.

## 2. Prefix reservation (explicit refusal beats silent fallback)

Any v1 request for alias prefix `hb_strongbox_` returns ATTESTATION_IMPOSSIBLE_V1
with docs link. A key created Software stays Software-labeled for its lifetime
(never silently promoted; rotation documented in release notes).

## 3. Verified-boot binding per key (recorded now, SE-bound later)

`verifiedbootstate-at-creation` + rollback-index stored alongside the key-flow
diagram (security/key-flow.dot). Phase-4 SE keys additionally bind the vbmeta
digest; v1 already stores the digest field so migration is additive.

## 4. Property gate (release assert)

`ro.hardware.keystore` reports `software` / `tee` ONLY where actually backed --
NEVER `strongbox` on v1 (a false StrongBox attestation breaks enterprise MDM
trust permanently once discovered). Gatekeeper enrollment: PIN-derived, host
verdict authoritative (lockscreen-policy.md S3 single-lock authority).

## 5. Threat placeholder (S23 row, DEFERRED-PHASE4)

`Discrete-SE / eSE` class threats S/T/I/R mapped to controls TBD -- the row exists
so nobody ships SE-dependent features (passkeys-sync, car-key, payment) on v1
software keys by accident. Each such feature MR must cite ch.08 S26 and is
rejected pre-Phase-4.

## 6. Phase-4 entry gates (gates, not dates)

Discrete-SE driver + HAL on >= 1 SKU; third-party tamper evaluation scoped;
security_level=StrongBox attested end-to-end on sacrificial units (pentest scope
extended: key-extraction resistance TESTED, not datasheet-asserted); v1 software
keys re-wrapped via migration ceremony. Until all four: Settings row reads
"Not available on this device (v1)".
