# vb-state-machine.md -- verified-boot state machine handlers (ch.08 S27, S2)
# Owner: Security + UI * States driven by ro.boot.verifiedbootstate; About shows
# the same word the boot screen showed (screenshots and Settings agree).

| State  | Meaning                  | Handler |
|--------|--------------------------|---------|
| GREEN  | locked + verified        | normal boot, no warning; About "Verified boot: on" |
| ORANGE | unlocked bootloader      | 5s dwell warning every boot (power-button skips, never skippable-by-default); About "Unlocked -- not for daily use"; guide = offline re-lock HTML in recovery |
| RED-R1 | corruption (dm-verity)   | halt; "Try again" once then slot-fallback (attempt 2 of 2 shown); factory-reset routes to halide-wipe --verify (never one-tap); support QR = redacted vbmeta digest + rollback index + slot (no IMEI/IMSI) |
| RED-R2 | rollback refused         | halt; update-only path ("Install latest"); NO "boot anyway" button (its absence is the control) |

Exact screen copy lives in vb-screens.md (wording drift = P1 trust bug).
Footer on every failure screen: "Support will never ask for your PIN".
Support playbook: ask Code (VB-R1/R2) + QR digest; R1 x2 unresolved => RMA
quarantine (half-verified device never ships back as clean); every case files
security/vb-fail-<date>.md (trend input to the S24-family review).

Drills/tests: quarterly sacrificial bit-flip (RED-corruption screen + code + QR
shape); quarterly rollback-refusal (RED-rollback copy + fastboot-bypass refused
+ logged); orange-dwell timing on eng builds (skip-hold <= 5s). Eng VERITY-OFF
watermark never appears on release RED/ORANGE screens (vb-state-check.sh asserts).
