# policy-<fleet>.md TEMPLATE -- enterprise fleet policy (ch.08 S20 wipe-at-N, S21 MDM)
# Copy to security/policy-<fleet-name>.md per enrolled fleet. Owner: Security + Fleet admin.
# Consent text committed here so there are no surprise wipes.

| Field | Value |
|---|---|
| Fleet | TODO (name + MDM endpoint ref) |
| wipe-at-N | TODO (N >= 10; v1 default OFF -- wipe-offer at 30 instead) |
| Pre-enrolment notice | TODO (date + text shown to admin AND user) |
| Attestation upload | TODO (MDM receipt endpoint; per-device WIPE lines, S21) |
| Escrow slot | TODO (demanded / not-demanded; never universal backdoor, S9) |
| Quarterly lot summary | TODO (accept-rate, blind-canary rate, tool versions, S28) |

Rules: wipe-at-N triggers the S21 halide-wipe --verify flow + attestation line
(WIPE <sku> <timestamp> <operator-confirm-id> <verify:PASS> <header-sha-new>).
Both fleet admin and user notified pre-enrolment (consent text above).
