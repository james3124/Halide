# drills/README.md -- incident-drill records (ch.08 S12, rehearsed annually)
# Owner: Security * Tabletop (all leads, 90 min) + live-fire (lab red-team night).
# Each drill produces MAX 3 action items tracked to closure before the next drill.

Scenario rotation: (a) malicious bridge-parser RCE (SOCKETS.md threat notes =
the playbook); (b) signing-subkey compromise (revocation OTA walked
click-by-click); (c) modem-driven exfiltration claim (QRTR audit + nft counters
as evidence); (d) stolen dogfood unit with pre-patch build (remote-wipe +
transparency-log forensics).

Live-fire: eng build with planted vuln (known CVE reintroduced in sandbox
branch); blue team must detect via fuzz/CI + patch + advisory-draft within the
SLA clock (timed live against the S15 rubric).

## Drill template (copy to drills/<YYYY-MM-DD>.md per drill)

| Field | Value |
|---|---|
| Date / kind | TODO (tabletop / live-fire) |
| Scenario | TODO (a/b/c/d or planted-CVE id) |
| What worked | TODO |
| What was slow | TODO |
| What lied (dashboards that lied get fixed first) | TODO |
| Action items (<= 3, owner + date each) | TODO |
| Anomalies-or-none | TODO (required line) |

No drills filed yet (TODO until first cycle).
