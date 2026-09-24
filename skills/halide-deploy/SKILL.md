---
name: halide-deploy
description: Use when deploying Halide builds from a phone or low-RAM device, planning a builder-only flash, or running a staged OTA rollout
---

# Halide Deploy

## Overview
Phone-safe deploy: plan-only on low-RAM, builder-only flash.
Never flash from the phone itself. Plan here, flash on builder.

## When to Use
- Deploying Halide OTA or factory image from phone / Termux
- Low-RAM environment where full build or flash is unsafe
- Staged rollout (1 / 10 / 50 / 100) with halt checks
- Verifying signing, AVB, and rollback protection before release

When NOT to use: local dev iteration, emergency unbrick (use builder console directly).

## Workflow

1. Pre-flight checks (phone-safe, read-only):
   - Run smoke tests: `./scripts/smoke.sh`
   - Run budget check: `./scripts/budget.sh`
   - Run socket audit: `./scripts/socket-audit.sh`
   - Abort on any failure. Fix before proceeding.

2. Plan-only deploy preview:
   - Run: `./deploy.sh plan --target <device> --slot all`
   - Review partition list, sizes, AVB descriptors, signatures.
   - Do not pass `--flash` or `--apply` on phone.

3. Handoff to builder for real flash:
   - Copy artifacts + plan output to builder host (scp/rsync/USB).
   - On builder only: `./deploy.sh flash --verified`
   - Verify AVB, vbmeta, and signatures match plan.

4. Staged rollout 1 / 10 / 50 / 100:
   - Stage 1: 1 canary device, 24h soak, check boot + radio + rollback index.
   - Stage 10: 10 devices, halt on any bootloop, brick, or AVB failure.
   - Stage 50: 50 devices, halt if crash rate >1% or battery drain anomaly.
   - Stage 100: full fleet, monitor OTA success rate and rollback signals.
   - Halt rules: any signature mismatch, AVB bypass request, or 2+ failed boots = stop rollout, freeze channel, page release owner.

## Safety Rules
- Never flash from phone. Phone is plan-only.
- Never bypass AVB, signing, or rollback protection.
- Never force-flash with `--no-verify`, `--disable-verity`, or similar.
- Two-person ceremony: one prepares plan, second verifies hashes + signs off.
- Keep builder keys offline; log every flash with hash + operator IDs.

## Quick Reference
- `./scripts/smoke.sh` - pre-flight health
- `./scripts/budget.sh` - RAM/storage budget
- `./scripts/socket-audit.sh` - open socket audit
- `./deploy.sh plan` - safe on phone
- `./deploy.sh flash` - builder only

## Common Mistakes
- Flashing from Termux on low RAM -> OOM / corrupt write. Fix: plan-only here.
- Skipping socket-audit -> leaked debug port ships. Fix: audit is mandatory.
- Jumping stages (1 -> 100) -> fleet-wide brick. Fix: follow 1/10/50/100.
