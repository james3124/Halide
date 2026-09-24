# DEPLOY CHECKLIST - Phase-3 Gate
# phone-safe text only, ascii, short lines
# all boxes must be checked before release

- [ ] Phase-3 entry criteria met
  Owner: rel-eng
  Evidence: hybrid/logs/phase3-entry.log

- [ ] Phase-3 exit criteria met
  Owner: rel-eng
  Evidence: hybrid/logs/phase3-exit.log

- [ ] 7-day dogfood run complete, no P0
  Owner: qa-lead
  Evidence: hybrid/logs/dogfood-7day.log

- [ ] AVB green, verified boot ok
  Owner: sec-lead
  Evidence: hybrid/logs/avb-verify.log

- [ ] Rollback demo passed
  Owner: rel-eng
  Evidence: hybrid/logs/rollback-demo.log

- [ ] SBOM published and stored
  Owner: sec-lead
  Evidence: hybrid/manifests/sbom.spdx

Release rule: manual approval + 2 signs.
Never auto-flash from CI.
