# Incident Response Runbook — From Report to Retrospective (hours, not weeks)
**Parent: ch.08 §§11–13, SECURITY.md · Owner: Security (commander) + Release (button) + QA (repro) · Severity rubric shared with §11**

## 1. Severity & clocks (same bins as CVE triage — one language everywhere)

P0-CRIT (RCE-as-root, verified-boot bypass, lockscreen bypass, container→host escape, active exploitation): acknowledge 4h, fix-or-mitigation 7 days, hotfix train same-week (ch.09 §3 hotfix lane). P1-HIGH (RCE-as-app, modem-data leak, permission split-brain in wild, rollback-protection failure): acknowledge 48h, fix ≤30 days (monthly train). P2-MED (info-leak non-PII, DoS-by-app-crash, theoretical-without-PoC): monthly train, 90-day cap. Active-exploitation flag auto-upgrades any bin to P0-CRIT handling (exploitation evidence: telemetry report, researcher PoC-with-traffic, carrier/fleet anomaly — gut feeling doesn't upgrade, evidence does).

## 2. First 24 hours (checklist — run it, don't improvise it)

1. Open `security/IR-<Y>-<NNN>.md` from template (reporter, received-ts, severity-proposed, affected versions/SKUs, evidence links, embargo-needed?).
2. Reproduce on lab unit matching reporter's fingerprint (exact version+SKU — wrong-version repro wastes the clock; fleet-matrix in ch.07 §11 tells you which unit).
3. Scope: which components (threat-model file section cited — the model tells you blast radius), which builds (MANIFEST range), user-action needed? (none / update / PIN-change / reflash — decided early, communicated early).
4. Contain (if active): kill-switch options ranked — staged-OTA halt (ch.09 §9 auto-halt honored manually too), advisory to fleet admins (P3 channel, ch.01 §11), worst-case feature-flag kill (bridge kill-switches documented per bridge: `halide-<x>-bridge --safe-mode` degrades gracefully — safe-modes tested quarterly, not invented during incidents).
5. Reporter comms within SLA (48h triage promise from SECURITY.md kept visibly — silence breeds disclosure-without-coordination).

## 3. Fix, verify, ship (embargo branch per §13 where needed)

Fix MR references IR id; verification = PoC-now-fails + regression test committed (the PoC becomes a test — every incident leaves a net) + attack-test-plan row added if new class (§5 lockscreen-list or §2 adversarial rows grow). Ship via hotfix or monthly per severity; staged rollout watched at 1% for 24h for security fixes touching radio/boot (extra bake — security fixes are high-blast-radius by nature). Advisory published (template ch.08 §8: affected/impact/action/verify-command) + reporter credited as agreed + CVE filed where applicable.

## 4. Retrospective (blameless, 60 min, ≤7 days post-ship — skipped retros guarantee repeats)

Template `security/IR-RETRO-<id>.md`: timeline (detection→triage→fix→ship with timestamps — where did the clock bleed?), which control should have caught it (threat-model row cited — model updated same retro or the retro isn't done), test added (link), process change (one, owner, date — three max per §12 drill rule pattern), disclosure quality self-grade (reporter surveyed: would-report-again? — researchers who won't return are a metric, ch.11 §11-adjacent). Retro attended by fixer + reviewer-of-the-buggy-code + Security (no managers unless invited — safety first, rank second).

## 5. Fleet/enterprise lane (P3 promise kept under pressure)

Fleet admins get: pre-notification T-24h for P0 (embargoed channel), per-serial affected check (`halide-fleet-check --ir <id>` outputs affected/needs-action per enrolled serial — no spreadsheet forensics), wipe-vs-patch guidance per IR (patch preserves, wipe attested — runbook-recovery §4 attestation reused). Post-incident fleet report: patched-count + outstanding with dates (auditors close loops on this document).

## Verification

- [ ] Annual tabletop + live-fire drills green (08 §12); template files exist; last retro's action items closed before next drill.
