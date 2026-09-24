# embargo-branch.md -- embargo handling procedure (ch.08 S13, 90-day default)
# Owner: Security * Embargo branch lives in a SEPARATE repo (not a hidden branch
# in the public one -- history leaks). Classification: this procedure is public;
# embargo CONTENTS are need-to-know until disclosure day.

## 1. Access list (4 named people per incident, revoked post-ship automatically)

Fix owner + Security + one QA + release-button-holder. Pentest-found issues:
testers join the 4-person list for their own findings only.

## 2. Build hygiene

Test builds from the embargo branch carry EMBARGO-<id> watermark + 7-day expiry
(ch.09 S12 nightly-expiry machinery reused -- a leaked embargo build is
time-boxed by construction). Credit-wall update MR rides the embargo branch
(S29 -- the wall never leaks via early commit).

## 3. Timeline (default 90 days, ch.08 S18/S13)

| Event | Clock |
|---|---|
| Report received | T+0 |
| Triage (48h SLA) | T+48h |
| Pre-notification (carrier security contacts + enterprise P3 fleet admins) | T-7 days |
| Disclosure day: fix + advisory + CVE + dogfood fast-track OTA + retrospective scheduled | T+90d |

## 4. Embargo-break (leak) procedure

Immediate FULL disclosure (no partials -- partials arm attackers without helping
defenders) + compress remaining timeline to 48h + postmortem on the break itself.
