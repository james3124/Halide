# Runbook — First Boot & Provisioning (`halide-firstboot.service`)
**Parent: ch.05 §8, ch.08 §3 · Runs once (`ConditionFirstBoot=yes`) · Must complete offline-capable**

## 1. Ordered steps (abort = stay in provisioning, never half-provisioned daily driver)

1. `machine-id` + SSH host keys generate (dropbear/ssh off by default — remote-debug is opt-in with pairing code, ch.05 §8).
2. Storage: expand userdata to full flash → verify sizes vs `flashmap.json` → LUKS2 encrypt (Argon2id params per ch.08 §9) unless factory already did.
3. Identity: hostname `halide-<sku-short>-<rand4>` (user-renamable), user `halide` exists from image hooks (ch.05 §8) — set nothing silently: locale/timezone from EL0 MCC suggestion shown as pre-selected choice, not auto-applied without confirm.
4. Lockscreen PIN ≥6 mandatory (ch.08 §3 — no Skip; enterprise policy can raise length, tested in `tests/firstboot-pin.sh`).
5. Modem enable gate: PIN set + encryption verified → then SIM PIN prompt (if locked) → MM register attempt with progress (not silent 90s — progress text + cancel).
6. Container first start: `halide-android-prepare` version check (ch.04 §15) → `sys.boot_completed` poll ≤120s → drawer generation (ch.05 §11) → permission-map defaults applied (all default-deny, first-use prompts later — no pre-grants).
7. Telemetry consent: explicit opt-in screen (default off; what leaves the device listed line-by-line — ch.10 §10 pipeline respects off with zero egress, tested by `tests/telemetry-off.sh` capturing 10 min of traffic = 0 non-essential packets).
8. Done card: versions (tap → full MANIFEST SHAs), emergency-call status for this build (VERIFIED/UNTESTED per ch.07 §10 — shown here, not buried), backup reminder with one-tap first backup.

## 2. Failure branches (each tested in CI on VIRT + quarterly on hardware)

| Failure | Behavior | Recovery |
|---|---|---|
| Power loss mid-encrypt | resume encrypt on next boot (LUKS header magic check → continue, never reformat over partial) | automatic + progress restored |
| No SIM / SIM locked, user skips | continue offline; modem stays rf-killed; persistent-but-dismissible "Insert SIM" card | Settings → Mobile re-runs step 5 standalone |
| Container never boot_completed | finish host provisioning WITHOUT Android (banner + "Retry Android setup" card); host fully usable | retry button re-runs step 6 with log export offered |
| User forgets PIN at step 4 | no recovery yet (no data) → "Start over" resets to step 1 in one tap | documented, no shame wording |
| Telemetry screen skipped (back button) | treated as declined (explicit opt-in §1.7 — skip ≠ consent) | toggle later in Settings → Privacy |

## 3. Timing budget & test

Total ≤6 min attended on REF-A (measured in `tests/firstboot-timing.sh`: per-step timestamps, slowest step flagged). First-boot is the most common QR code-scan moment — test with a non-engineer quarterly (ch.09 §10 fresh-eyes rule applies here too).

## Verification

- [ ] All 5 failure branches demonstrated on hardware; timing budget met; skip-telemetry = declined proven by packet capture.
