# biometric-policy.md (enforcement copy) -- fingerprint / face v1 gates
# Parent: hybrid-os-plan/biometric-policy.md * Owner: Security/Android
# v1: PIN-first, biometrics strictly gated. tests/lockscreen-policy.sh asserts
# the doctrines below (never-key-deriving, 2D-face refusal, single lock authority).

## 1. Doctrine (binding)

- v1 gates NOTHING on biometrics: the lockscreen PIN/passphrase is the SOLE
  cryptographic secret (wraps LUKS/FBE keys, ch.08 S9). Biometrics are
  convenience-unlock only -- never key-deriving, never recovery-capable.
- 2D-camera face = explicitly refused as lockscreen unlock v1 (photo-spoof
  trivial; app-level convenience only where the app accepts it, never lockscreen).
- Fingerprint HAL (android.hardware.biometrics.fingerprint@2.3+) lands as
  INFORMATIONAL only if: mainline driver exists AND template storage is
  TEE-or-host-secure-element bound with a published threat note. Sensors without
  open calibration are documented-absent: NO fake enroll UI ships (an enroll
  screen that cannot secure templates is worse than none).
- Single lock authority: Android BiometricPrompt granted != host store unlocked --
  host keyring requires PIN after reboot (no convenience creep across the boundary).

## 2. Bring-up guardrails (if a sensor qualifies)

1. Host driver proves reset/enroll-interrupt/power-gating via sysfs first.
2. Template storage audit: TEE secure storage with rollback-protected monotonic
   counter, or host LUKS-backed store 0600 halide-bio + audit log.
   spool-in-world-readable-tmpfs = instant fail, no appeal.
3. Anti-spoof minimum + QA bypass demo recorded (pass = reject >= 9/10, 1 miss explained).
4. Fallback honesty: 5 failed attempts -> PIN; enroll count + last-used in Settings.
5. Bridge rule restated: biometric grant never unlocks the host keyring alone.

## 3. Class honesty table (per sensor, committed -- self-graded CLASS_3 forbidden)

| Sensor | Modality | Spoof test | Template home | Class claim | Lockscreen? |
|---|---|---|---|---|---|
| TODO-sku-sensor | TODO | TODO (recorded) | TODO (audited) | CLASS_2 max v1 | convenience only |

Class-3 claims require third-party evaluation evidence (review checklist rejects
self-awards). No enroll UI ships for sensors failing S2; host keyring stays
PIN-after-reboot (verified per release).
