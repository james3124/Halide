# ADVISORY-TEMPLATE.md — CVE advisory template (ch.08 §8 compromise runbook + §11 SLA)
**Owner: Security · Phase: all — fill every bracket; embargo date honored per ch.08 §13 (90-day default)**

```markdown
# HALIDE Security Advisory HSA-<YYYY>-<NNN>

**ID:** HSA-<year>-<nnn> (CVE-<id> if assigned)
**Affected:** versions <  <x.y.z>  / builds before  halide-<date>-<sha12>  (SKU list)
**Severity:** <Low|Medium|High|Critical> — CVSS 3.1 base score <0.0> (<vector string>)
**Impact:** <one paragraph, plain language>
**Fix commit:** <commit sha12> — shipped in build `halide-<date>-<sha12>` / OTA release <train>
**Workaround:** <none | exact steps>
**Verification (user-runnable):**

avbtool info_image --image vbmeta.img | grep -i key     # or the fix-specific command

**Embargo until:** <YYYY-MM-DD> (disclosure clock: report +90d default, ch.08 §13)
**Credit:** <reporter-chosen: name / handle / anonymous> (PGP fingerprint suffix optional)
**Notes:** <anomalies-or-none line — anomalies spelled out, never empty>
```

Rules: advisory text ships the same hour the fix is published (wall + advisory atomic, ch.08 §29); translations top-12 languages; published in `security/advisories/` + transparency repo.

Expected: filled template reviewed by Security + Arch before publish; embargo breaches = P0 process bug.
