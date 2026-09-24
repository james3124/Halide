# HALIDE phone-safe build (limited RAM)

This `hybrid/` tree is a PHONE-SAFE skeleton. It does NOT run full AOSP/kernel builds.

Why: full factory build needs x86_64 Debian 12+, 32GB RAM, 500GB NVMe (ch.00 builder guide).
This phone: aarch64, ~3.7GB RAM / ~1.2GB avail, ~20GB free. Full `repo sync` (~120GB) + AOSP
(~2-4h, 32GB) would OOM and fill disk.

What IS safe here:
- Edit manifests, fragments, unit files, bridge protos (text only)
- Run `scripts/budget-check.sh` and `tests/smoke.sh` (KBs of RAM)
- Draft DT overlays and panel.json by hand

What is BLOCKED on this phone (guarded in scripts/build-all.sh):
- `repo sync`, kernel compile, AOSP compile, debootstrap, image assembly, OTA payload gen
- Those need a cloud builder or PC. See `manifests/MANIFEST.lock` pins to use there.

Low-spec target (binding): 4GB RAM / 32GB storage phones — see `hybrid-os-plan/low-spec-tier-4gb-32gb.md`.
All changes here must keep RAM ≤3320MB committed + reserve, factory image ≤11GiB.
