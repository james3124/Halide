# Biometric Policy — Fingerprint / Face v1 Position & Bring-Up Guardrails
**Parent: ch.04 HAL table (informational), ch.08 threat model · Owner: Security/Android · v1: PIN-first, biometrics strictly gated**

## 1. Position (explicit so roadmap pressure can't smuggle weak biometrics)

v1 gates NOTHING on biometrics: lockscreen PIN/passphrase is the cryptographic secret (wraps LUKS/FBE keys, ch.08 §9); any biometric is convenience-unlock only, never key-deriving, never recovery-capable. Fingerprint HAL (`android.hardware.biometrics.fingerprint@2.3`+) may land as informational if the sensor has a mainline driver AND template storage is TEE-or-host-secure-element bound with a published threat note; ultrasonic/optical-under-display sensors without open calibration are documented-absent (no fake enroll UI — an enroll screen that can't actually secure templates is worse than no enroll screen). Face unlock v1: 2D-camera face = explicitly refused as unlock (photo-spoof trivially; offered only as app-level convenience where the app accepts it, never lockscreen). This section exists because every phone-plan thread eventually demands "but fingerprint?" — the answer is written here with conditions, not postponed to release week.

## 2. Bring-up guardrails (if a sensor qualifies)

1. Host driver proves reset/enroll-interrupt/power-gating via sysfs before any Android HAL (same host-first discipline as modem/GNSS).
2. Template storage audit: where bytes live (TEE secure storage with rollback-protected monotonic counter, or host LUKS-backed store with `0600 halide-bio` + audit log) — `spool`-in-world-readable-tmpfs is an instant fail with no appeal.
3. Anti-spoof minimum: live-ness signal required for under-display optical (exposure/ppp variance check); capacitive/live-finger baseline for swipe/area sensors; bypass demo (printed fingerprint / photo) attempted by QA and recorded (pass = rejected ≥9/10, with the 1 miss explained, not hidden).
4. Fallback honesty: 5 failed attempts → PIN (AOSP default kept); biometric enroll count + last-used shown in Settings (stale biometrics visible, removable one-tap).
5. Bridge rule: Android `BiometricPrompt` granted ≠ host store unlocked — host keyring requires PIN after reboot (same as stock semantic; no convenience creep across the boundary).

## 3. STRONGLY-CLASS-3 honesty table (per sensor, committed, no marketing grades)

| Sensor | Modality | Spoof test | Template home | Class claim | Lockscreen? |
|---|---|---|---|---|---|
| <sku sensor> | capacitive area | printed-finger 9/10 reject | TEE/secure-element (audited) | CLASS_2 max v1 | convenience only |
| <under-display> | optical | photo/printed 6/10 reject | host LUKS store | convenience | NO (does not meet bar) |

Class-3 claims require third-party evaluation evidence — self-graded CLASS_3 is forbidden (write that in the review checklist so nobody self-awards it).

## Verification

- [ ] No enroll UI ships for sensors failing §2; spoof demos recorded; host keyring still PIN-after-reboot.
