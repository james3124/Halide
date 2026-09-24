# Runner provisioning -- CI runner classes (ch.09 S23).
# Three classes, never mixed. No snowflake runners: any runner that cannot be
# re-imaged from definition in <= 30 min is decommissioned, not debugged.
# Owner: Release (primary), infra (secondary). ASCII only.

## Classes

| Class | Runs | Lab USB | Notes |
|---|---|---|---|
| builder | build-all.sh, heaviest | no | docker digest must match ci/Dockerfile pin |
| virt-ci | per-MR fast jobs | no, QEMU-only | MR burst capacity |
| lab-runner | REF units via USB/UART | yes | udev symlinks /dev/halide/<unit-label>, never ttyUSB roulette |

All boot from the same pinned runner-image doctrine (Debian stable digest +
ci/packages.lock-style freeze + recorded kernel version).

## Provisioning (infra/runners/provision.sh --class <c> --id <rNN>)

1. Netboot/netinstall from canonical image SHA (SHA verified pre-install;
   mismatch = abort + alert).
2. cloud-init/ansible applies infra/runners/<class>.yaml (users, mounts,
   firewall, cron guards).
3. Enroll in infra/runners/inventory.csv (id, class, MAC, TPM EK pub if
   present, image SHA, owner, date).
4. Self-test (disk >= 200G free, docker digest matches ci/Dockerfile pin,
   no testkey material via grep -r testkey keys/, egress allowlist enforced).

Only selftest-green runners join the pool (scheduler polls inventory health
flag, never a static hostname list).

## Hardening baseline (all classes)

- SSH ed25519 only, PasswordAuthentication no, fail2ban.
- Builds run as unprivileged builder uid, no sudo; docker-in-docker banned.
- Secrets never on disk (OIDC short-lived tokens <= 1h).
- Egress allowlist (snapshot proxy + package mirror + git remotes only).
- Full-disk encryption on lab-runners + builders (TPM-sealed or sealed envelope).
- Host packages auto-update weekly; runner image rebuilt monthly
  (drift > 30 days = STALE-RUNNER label, scheduler drains it).

## Rotation

Runner images rebuilt monthly + on any PATCH-NOW toolchain CVE. Deploy keys +
OIDC trust rotated quarterly (rotation log: old/new fingerprints, re-enrolled
count). Compromised-runner response reuses the ch.09 S13 builder-compromise
ladder. Annual game-day: deliberately mis-provision one staging runner
(wrong digest + stale packages); provision/selftest must reject it before it
takes a job (reject-failure = P0 infra bug).

## Capacity

Floor: >= 2 builders, >= 2 virt-ci, >= 1 lab-runner per 2 REF units.
MR wait > 30 min pages Release secondary. Nightly window 22:00-06:00 reserved
for full builds with lab-calendar preemption rules.
