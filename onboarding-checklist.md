# Onboarding Checklist — Zero to First Merged MR in 2 Weeks (P4 + new-hire path)
**Parent: ch.01 P4 story, ch.11 §8, devloop-faq · Owner: Program (content) + assigned buddy (execution)**

## 1. Day 1–2: orientation (no code — context before commits)

[ ] Read ch.00 index + ch.01 vision/DoD/non-goals (quiz: name 3 non-goals — ch.01 §4 exists to be quoted).
[ ] Flash lab unit from runbook (factory §10 lane, supervised) + capture UART boot (02 §11 discipline).
[ ] Run `halide-log-collect --redact`, read the bundle (support script §2 vocabulary).
[ ] Buddy assigned (named in `program/onboarding/<you>.md` with start date — no buddy = onboarding hasn't started).

## 2. Day 3–5: first green (touch the machine safely)

[ ] Full VIRT nightly boot locally (ch.09 §11 pipeline shape understood, not just read).
[ ] Run one contract test + one harness script (bridges/tests/ + tests/, exit-code contracts ch.10 §7).
[ ] Merge a docs/nit MR (repo-layout §3 feature-branch flow practiced end-to-end: branch → CI → review → land).

## 3. Week 2: first real MR (scoped by buddy — subsystem-shaped, gate-evidenced)

[ ] Change includes gate evidence (which hardware run + log links per devloop-faq §4 "works" definition).
[ ] Review SLA experienced both sides (author once + reviewer-shadow once with buddy narrating the §2 checklist).
[ ] Retro 20 min with buddy: what was slow? (findings → doc bugs filed same day — onboarding friction is process data).

## 4. Done definition + anti-patterns (written so buddies can cite them)

Done = 1 merged behavior-or-fix MR + 1 filed-follow-up (everyone leaves onboarding with a follow-up — codebase familiarity proven by noticing something). Anti-patterns: week-1 kernel rewrite (fragments first, ch.03 §11), private-blob commit (keys/scanner §rule, ch.08 §8 — violation = immediate revert + blameless retro, not punishment), DM questions (devloop-faq §5 public-channel rule from day 1).

## Verification

- [ ] Trailing-quarter onboarding survey: median time-to-first-merge ≤10 business days; friction bugs filed per onboarding ≥1.
