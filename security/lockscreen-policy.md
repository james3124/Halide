# lockscreen-policy.md -- lockscreen attempt-limit enforcement (ch.08 S20, S3, S9)
# Owner: Security * Enforced by host Phosh lock + halide-pin-derive.
# This file is what tests/lockscreen-policy.sh and tests/lockscreen-5.sh assert.

## 1. PIN rules (first-boot S3 + every PIN change)

- PIN >= 6 enforced; rejects trivial blocklist (security/weak-pins.txt Part B:
  123456, 000000, birth-year-trivial list of 50); rejects repetition of current PIN.
- First-boot: force PIN + auto-encrypt (no "skip").

## 2. Escalation ladder (exact user-visible strings -- support and docs match)

1. Attempts 1-5: no delay. "Wrong PIN. N attempts remaining before delay."
   (N = 10 - count; honest countdown, no scare offset.)
2. Attempt 10: 30s delay (enforced in the unlock daemon, not the UI -- killing
   Phosh does not skip it). Message with live countdown + "Emergency call still
   available" (emergency path never gated -- regulatory).
3. Attempts 11+: delay doubles per failure (30s -> 60s -> 120s ... capped at
   15 min). Names the wait + offers "Forgot PIN? Recovery options" (recovery =
   authenticated backup/restore path, never a bypass).
4. Attempt 30: wipe-offer screen (NOT auto-wipe v1). "30 wrong attempts. Erase
   this device to protect your data? [Erase] [Keep trying]". Erase requires
   typing ERASE + PIN-length confirm (pocket-tap cannot wipe).
5. Enterprise wipe-at-N (MDM-set, N >= 10, recorded in security/policy-<fleet>.md):
   at N the device crypto-erases per S21 + writes wipe attestation. Fleet admin +
   user both notified pre-enrolment (no surprise wipes -- consent text committed).

## 3. Anti-footgun rules (binding)

- Attempt counter survives reboot (tamper-evident host state under
  /userdata/.halide/lockstate, fsync per attempt -- power-pull must not reset it).
- Delay timer pauses (not resets) on reboot.
- Biometrics (where present) never reset the PIN counter.
- Single lock authority: container-side Android keyguard is slaved to the host
  verdict -- Android keyguard unlock without host unlock = rejected + logged.

## 4. Key derivation binding

- halide-pin-derive wraps the LUKS key (kdf-registry.json + luks2-params.conf);
  brute-rate-limit proven by tests/lockscreen-5.sh (12-wrong run: delays at
  10/11/12 + reboot-persistence + emergency-dial reachable + wipe-offer absent
  before 30). Annual full 30-attempt + enterprise-wipe path on sacrificial unit.

## 5. Testing

- tests/lockscreen-5.sh (lab units, HALIDE_LAB=1): scripted wrong-PIN run.
- Quarterly lockscreen-bypass session: 5 published patterns attempted, each
  recorded PASS/FAIL (FAIL = P0 same day + embargo if exploitable per S13).
