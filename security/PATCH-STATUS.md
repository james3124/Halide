# PATCH-STATUS.md — patch-level dashboard (ch.08 §11; updated weekly during dogfood, red entries >45d escalate to Arch)
**Owner: Security · Phase: 2+ — disposition per CVE: patched / not-affected-with-reason / mitigated-by-config + test**

| Stream | Target | Status | Age (days) | Owner | Notes |
|---|---|---|---|---|---|
| Android SPL | merged ≤30d, hard gate 60d (ch.01) | green — 2026-08-05 SPL merged | 9 | gita | bulletin delta attached to release notes |
| Kernel LTS stable | merged ≤30d | green — 6.6.y stable queue clean | 11 | ana | cvecheck-equivalent scan attached |
| Debian security pocket | merged ≤30d | green — debsecan host clean | 11 | dana | debsecan output archived per release |
| Quarantine CVEs (disposition pending) | 45d max | yellow — 1 entry, 32d | 32 | ken | BUG-sec-221, fix in next train |

## Rules

- Stale-patch dashboard reviewed weekly during dogfood; red (>45d) escalates to Arch with a dated plan.
- Release notes carry all three scans (kernel CVE lag list, AOSP bulletin delta, `debsecan`) with disposition per CVE.
- Hard gate: patch level ≤60 days or release train halts (ch.01 §5 DoD security row).

Expected: `cvecheck`-equivalent output attached per release with zero unexplained entries.

Fail action: any red row without a dated plan = release-train freeze until triaged.
