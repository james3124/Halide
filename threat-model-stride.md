# Threat Model — STRIDE per Component (the file attackers read; we wrote it first)
**Parent: ch.08 §1 · Owner: Security (all areas contribute their rows) · Review: per release + on any new socket/HAL/bridge**

## Method (lightweight STRIDE — table, not tome)

Per component: Spoofing / Tampering / Repudiation / Information-disclosure / Denial / Elevation — one line each with existing control + residual rating (MITIGATED / ACCEPTED-with-reason / OPEN-with-bug). OPEN without bug ID fails review. ACCEPTED requires named rationale + expiry (accepted-forever is OPEN with shame).

## 1. Bootloader + AVB chain (ch.03 §6/§18, ch.08 §2, 08-A/08-B)

- Spoofing (evil boot image): MITIGATED — AVB flag-2 green + rollback monotonic (quarterly refusal drill).
- Tampering (persist/EFS rewrite via unlocked tooling): MITIGATED — lock-state + factory MAC/NVRAM verify (08-A/08-B); relock drill quarterly.
- Repudiation (deny flashing): ACCEPTED — flash-log + transparency entries exist for ours; attacker-with-physical-access repudiation out of scope (stated).
- Info-disclosure (keys in images): MITIGATED — pubs-only-in-git scanner + ceremony log (ch.09 ceremony §15).
- Denial (brick via bad flash): MITIGATED — size validation pre-flash + slot fallback + EDL last resort (documented per SKU).
- Elevation (unlock→root persistence): MITIGATED — unlock wipes + orange warning; relock only on signed images.

## 2. Kernel (ch.03 + 08 §16)

- Spoofing (fake device/firmware load): MITIGATED — module signing enforced + firmware SHA pin (BLOB-SHA256).
- Tampering (runtime patch via kprobes/kexec): MITIGATED — release disables (08 §16; eng-only, CI-grepped).
- Repudiation (exploit leaves no trace): MITIGATED — pstore/ramoops + auditd ruleset committed (`security/audit.rules`: module-load, mount, `ptrace`, keyring ops).
- Info-disclosure (KASLR defeat via dmesg/`/proc` leaks): MITIGATED — `DMESG_RESTRICT`, `kptr_restrict=2`, unpriv-eBPF off; quarterly `leak-check.sh` (boots + greps dmesg for addresses as unpriv user — addresses visible = fail).
- Denial (driver hang wedges phone): PARTIAL — watchdog + resin (ch.03 §19) recover; per-driver hang in dogfood = P1 with ramoops (ACCEPTED-with-recovery, not silent).
- Elevation (privesc to root): MITIGATED-LAYERED — CFI+SCS+KASLR+hardened-allocators (§16) + SELinux/AppArmor still containing a compromised root where possible (container-escape test proves residual, §attack-test-plan).

## 3. Bridges (ch.05 §9–10, bridges/* protocols — the highest-exposure userspace)

- Spoofing (fake peer on socket): MITIGATED — `SO_PEERCRED` allowlists + three-way MAC sync (sepolicy-deltas §5).
- Tampering (malformed frames): MITIGATED — versioned schemas + size caps + fuzz harnesses per parser (unknown-field reject, oversize close).
- Repudiation (bridge abuse deniable): MITIGATED — structured journal (CODE+BRIDGE+PEER) + metrics counters; split-brain alert (permission §2) is P0-metered.
- Info-disclosure (PII across boundary): MITIGATED — redaction rules (ril §5, log-collect), OTP scoping (smsc §3), no IMSI in committed logs (CI-grepped `\d{15}` rule, appendix-04A §1).
- Denial (parser hang/starve): MITIGATED — timeouts + queue caps + drop-newest-with-counter (never block-without-deadline); storm tests in contract suites.
- Elevation (container→host via bridge): MITIGATED — `execve` denied (seccomp), no shell-outs, minimal parsing in privileged context; escape-drill in attack-test-plan.

## 4. Android container (ch.04 + LXC + SELinux)

- Spoofing (rogue HAL service): MITIGATED — `service list` golden diff (appendix-04A §2) + manifest-pinned services; new service without manifest+sepolicy = review fail.
- Tampering (system partition at runtime): MITIGATED — dm-verity (08 §14 panic/EIO policy + quarterly flipped-bit drill).
- Repudiation: MITIGATED — logcat slices in bugreports + tombstones preserved to host `/var/crash`.
- Info-disclosure (host data visible in container): MITIGATED — bind-mount allowlist (ch.04 §15 config — mounts not in config can't appear; audit script compares); no direct ALSA/persist/EFS nodes.
- Denial (container wedge takes host): MITIGATED — cgroup limits (CPU/mem/pids in LXC config) + 3-crash banner rule (ch.05 §2 host survives).
- Elevation (container→host root): MITIGATED-LAYERED — userns idmap + SELinux container context + AppArmor + seccomp + no-new-privs on container init where compatible (each layer tested by disabling one in harness, ch.08 §4 — residual single-layer hold proven).

## 5. Modem/baseband-adjacent (ch.07, QRTR/QMI)

- Spoofing (fake cell): ACCEPTED-WITH-DISCLOSURE — baseband trusts network by design industry-wide; our posture: host-validated cell-change prompts (roaming §16), no silent IMSI-catcher resistance claims (stated non-goal honesty, ch.08 §1 scope).
- Tampering (baseband→AP via QRTR): MITIGATED — QRTR driver hardening (08 §16 allocators + `qrtr-ns` service allowlist: unknown service IDs logged + blocked by default `qrtr-policy.conf`, not auto-bound).
- Info-disclosure (location/IMEI to network): ACCEPTED — cellular protocol necessity; minimized elsewhere (no IMEI in logs, §3 row).
- Denial (modem crash wedges radio): MITIGATED — crash ladder (ch.07 §15) + crash-rate P0 rule.
- Elevation (RCE in modem → AP): CONTAINED — IOMMU (`ARM_SMMU`, ch.03 §12) + rproc sandboxing + QRTR policy; residual acknowledged (state-level baseband RCE out of scope v1, ch.08 §1 — stated, not hidden).

## 6. OTA/update + supply chain (ch.09, update-engine-internals)

- Spoofing (evil update server): MITIGATED — key-pinned payload verify + rollback-index (verify-before-write, §2 update doc).
- Tampering (build tampering): MITIGATED — two-builder repro as detector (ch.09 §13 compromise runbook) + transparency log + SBOM diff review.
- Repudiation: MITIGATED — signatures.json + ceremony log + transparency entries.
- Info-disclosure: MITIGATED — no secrets in images (scanner), redacted reports.
- Denial (forced-bad-slot brick): MITIGATED — tries-remaining fallback + power-yank test + slot-surgery UI (runbook-recovery §5).
- Elevation (update smuggles privilege): MITIGATED — same MAC/verity policies apply post-update (health-gate re-verifies `getenforce` + profiles before commit — commit gate includes posture check).

## 7. Lockscreen / auth / human layer (ch.08 §3/§9, firstboot, biometric-policy)

- Spoofing (smudge/shoulder/photo): MITIGATED-PARTIAL — PIN rate-limit + wipe-offer (ch.08 §9); biometrics convenience-only (biometric-policy §1 doctrine); 2D-face refused as unlock.
- Tampering (bypass via recovery/adb): MITIGATED — recovery auth-gate (runbook-recovery §3), `ro.adb.secure`, USB charge-only default (ch.08 §10).
- Repudiation (deny unlock attempts): MITIGATED — attempt counter + delay schedule logged (brute-rate evidence).
- Info-disclosure (notifications on lock): MITIGATED — sensitive-content hidden default (sender-only), OTP excluded from backups (smsc §3), per-app visibility setting.
- Denial (lockout by attacker with physical access): ACCEPTED — 30-attempt wipe-offer is user-chosen (enterprise can mandate); documented.
- Elevation (lockscreen bypass bugs): P0-class (ch.06 §4 overlay rule, ch.08 §11 rubric) + quarterly bypass-attempt session (QA tries 5 published bypass patterns against our build — recorded pass/fail).

## Residual register (ACCEPTED items tracked — acceptance is a finding, not a shrug)

| # | Residual | Reason | Expiry/review |
|---|---|---|---|
| R-1 | Baseband→AP advanced RCE | industry-wide modem trust boundary | per release (revisit with modem-fw changes) |
| R-2 | Fake-cell protocol trust | cellular design, no false claims | per carrier-matrix update |
| R-3 | Suspend-RAM key presence | standard mobile posture, stated | revisit with hardware memory-encryption SKUs |
| R-4 | Driver-hang recovery (not prevention) | availability vs perfection tradeoff | per dogfood P1 counts |

## Verification

- [ ] Every row has control + rating; zero OPEN-without-bug; ACCEPTED rows carry expiry; R-register reviewed per release.
