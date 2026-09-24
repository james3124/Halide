# attack-test-harness.md -- attack-test complements (attack-test-plan, threat-model)
# Owner: Security + QA * Cadence: per-release subset + annual full + pentest.
# Each battery maps to the harness that proves it; PASS = service-healthy-after
# + counters-match-expected (not merely "didn't crash"). Any per-release FAIL
# blocks release (dogfood-P0 rank).

## E. Container-escape battery (crown-jewel test)

| Case | Attack | Expect | Harness |
|---|---|---|---|
| E1 | binder-fuzz storm (1M corpus, E1-lite 100K per release) | zero host crashes, structured rejections | halide-fuzz-bridges corpus + contract suite |
| E2 | mount-namespace breakout (5 published techniques) | containment; /root/.halide-canary untouched | escape drill script (lab) + audit.rules canary alert |
| E3 | cgroup-release_agent write | neverallow/cgroupv2 blocks + alert | neverallow.te + release-gate-check.sh |
| E4 | one-layer-disabled runs (drop AppArmor, then SELinux, then seccomp) | remaining layers still hold (a miss = P0) | per-layer harness runs, documented hold/miss |
| E5 | malicious APK battery (10 crafted) | bridge rejections, split-brain counter 0 | bridge adversarial suites |

## B. Bootchain attacks

B1 old-image boot => refuse (avb-verify.sh + quarterly drill). B2 flipped-bit
=> specified panic/EIO (S14). B3 wrong-key relock => clean abort, never brick.
B4 evil-charger USB fixture => zero host response pre-unlock (charge-only default).
B5 cold-boot posture R-3 => init_on_free + no key material in ramoops (leak-check.sh).

## R. Radio-adjacent (honest boundaries)

R1 fake-cell fixture => roaming prompt + data-off default (log proves
prompt-then-decision). R2 modem-crash injection => S15 ladder. R3 SMS storms =>
dedupe exactness, no double-send billing. R4 OTP posture => non-allowlisted
package must NOT receive retriever broadcast (negative test).

## L. Lockscreen bypass session (quarterly, QA-led)

5 published patterns (USB-keyboard escape, notification deep-link smuggling,
overlay tapjacking, camera-from-lock intents, emergency-dial leak): each
PASS(blocked)/FAIL(P0 same day + embargo if exploitable). List refreshed within
a month of new published patterns (lockscreen-policy.md S5).

## Scoring

Per-release subset (E1-lite + B1/B2 + lockscreen-5 + bridge-flood smoke) green
with logs; annual full + pentest scoped (pentest-worksheet.md); results in
release-notes security section (counts + bins, details embargoed then disclosed).
