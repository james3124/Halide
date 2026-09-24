---
name: halide-power-triage
description: Use when triaging standby drain, wakeup storms, or thermal-throttle reports on Halide lab units
---

# Halide Power Triage

## Overview
Phone-safe power triage: read-only collection on lab units, analysis on builder.
Never bypass battery leads on dogfood units; never disable a correctness
workaround to "fix" power (WA-drift rule, power-regression-bisect S3).

## When to Use
- Standby drain beyond the 2x-stock envelope (ch.02 S6)
- Suspend residency below 90% overnight (ch.10 S3)
- Nightly power ALERT with 3-night evidence (power/ALERT-<date>.md)
- Thermal-throttle or skin-temp report (ch.10 S28)
- Soak slope-alert breach (tests/soak-alerts.conf)

When NOT to use: builder-only CSV linting (use scripts), release sign-off
signing (use qa/signoff-template.md).

## Workflow

1. Collect (lab unit, redacted):
   - `halide-power top --record 8h` CSV for overnight runs
   - `cat /sys/kernel/debug/wakeup_sources` top-10 diff vs baseline
   - `dumpsys batterystats` slice + modem DRX histogram
   - Freeze long-tail evidence: `tests/freeze-evidence.sh <trigger-id>`

2. Attribute by layer (power-regression-bisect S2 order: kernel first):
   - kernel: deep-residency drop, missing C-state, dmesg wakeup storm
   - HAL/blob: active-scenario drain only, HAL wakelock, DRX collapse
   - app-layer/bridge: idle drain with bridge CPU high, poll storm

3. File the verdict:
   - Regression: power/bisect-verdict-template.md copy with blamed commit
   - Long-tail: qa/digs/DIG-template.md copy with prevention item
   - Gate miss: wakelock-sprint issue with owner + date (not a footnote)

## Safety Rules
- Same unit, same meter, same ambient window per bisect (ch.10 S8)
- Calibration current (power/<sku>/calibration.md, <=6 months) or tag UNCALIBRATED
- Numbers carry the footnote set (ch.10 S12) or they are rejected
- No ship with open S1 power ALERT except documented dogfood exception

## Quick Reference
- `tests/suspend-stress.sh --redact` - 50-cycle gate wrapper
- `tests/soak-72h.sh --redact` - 72h rhythm + slope evaluation
- `tests/thermal-hints.sh` - trip-ladder sanity
- `power/<sku>/results-TEMPLATE.md` - per-release result sheet
