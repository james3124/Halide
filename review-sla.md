# Code Review SLA & Quality Bar — What "LGTM" Provably Means Here
**Parent: repo-layout §3, ch.11 §11 metrics · Enforced by branch protection + culture (this file is the culture half)**

## 1. SLA clock (business hours, reviewer-local honesty — no fake global 24h)

First response ≤1 business day (acknowledge + ETA, not necessarily approval); full review ≤2 business days (ch.11 §11 merge-latency metric reads this); author re-review after updates ≤1 business day. Stale MR (>5 days no reviewer action) auto-escalates: ping → second reviewer added → standup agenda (ch.11 §7) — no silent deaths. Hotfix/P0: 4h first response (ch.08 §11 severity rubric clock shared). Reviewer load cap: 3 active assigned MRs max (4th assignment reroutes — overloaded reviewers rubber-stamp; the cap is quality infrastructure).

## 2. Approval meaning (the checklist the approver implicitly signs)

Correctness (logic + boundary conditions + error paths return structured errors per bridge contracts, never bare -1), tests (contract/harness evidence linked for behavior change — "tested locally" without log link = changes-requested), security (new socket/parser → SOCKETS.md + threat note + fuzz corpus seed, ch.05 §10; new module → TECH-DEBT entry, ch.03 §20; new permission path → mapping-table row, bridges/permission), size/perf/power (image-size delta noted for preinstalled additions; wakeup-source/power impact considered for daemons — "runs every N s" requires the mA receipt), docs (plan/procedure change ships doc update same MR — doc-debt follow-ups expire in 7 days or auto-file). Nits (style/typo) never block alone (separate `nit:` prefix convention — blocking on nits is called out in review-retros).

## 3. Review-retros & calibration (reviews reviewed quarterly)

Sample 10 merged MRs/quarter (stratified: 3 clean, 4 normal, 3 hotfix): missed-bug hunt (would a checklist item have caught it?), SLA adherence, nit-block rate (target 0). Findings → update this file (living bar, versioned — bar-raises announced in monthly, never smuggled into a single MR's comments).

## Verification

- [ ] SLA dashboard green trailing quarter; retro completed with file updates or explicit "bar holds".
