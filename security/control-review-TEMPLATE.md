# control-review-<year>.md TEMPLATE -- annual control-effectiveness review (ch.08 S24 + S30)
# Copy to security/control-review-<YYYY>.md. Week-long, all leads + QA.
# Per family verdict: KEEP / TUNE / RETIRE-with-replacement (retire needs Arch +
# Security dual sign + ADR; no flag-day retirements -- migration window with both
# controls running). Max 3 action items per family (more = none get done).
# Owner: Security

Evidence packs live in review-evidence/<year>/ (seeded samples via
tests/review-sample.py --seed <year>; verdicts cite artifact hashes, not
"see dashboard"). Missing pack = family marked EVIDENCE-LATE (reviewed first).

| Family (plan ref) | Operated? (logs linked) | Caught anything? (counts) | Cost? | Verdict |
|---|---|---|---|---|
| Verified-boot S2 + dm-verity S14 | TODO | TODO | TODO | TODO |
| LUKS S9 + wipe-verify S21/S28 | TODO | TODO | TODO | TODO |
| AppArmor/seccomp/nft S10 | TODO | TODO | TODO | TODO |
| Patch SLA S11 + CVE triage S15 | TODO | TODO | TODO | TODO |
| Kernel hardening S16 | TODO | TODO | TODO | TODO |
| Lockscreen S20 | TODO | TODO | TODO | TODO |
| Researcher builds S22 + credit wall S29 | TODO | TODO | TODO | TODO |
| Supply-chain S23 | TODO | TODO | TODO | TODO |

Verdict thresholds (S30): KEEP requires evidence-complete + >= 1 caught-anything
event OR red-team proof the control would catch (untested + never-fired =
UNPROVEN, gets a live-fire task or TUNE). Output: risk-register delta to Program.
