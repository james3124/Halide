# review-evidence/<year>/ README -- evidence-sampling packs (ch.08 S30)
# Owner: per-family owner (table below) * Packs committed BEFORE review week or
# the family is marked EVIDENCE-LATE and reviewed first.

| Family artifact | Population -> sample | Owner |
|---|---|---|
| vb-evid.csv | 100% release vbmeta (flag-2+key+monotonic) + 1 bit-flip + 1 rollback log/quarter | Security/BSP |
| wipe-evid.md | all WIPE-VERIFY-FAIL + random 30 PASS re-verified + quarterly deep-reads | QA/Release |
| mac-evid.md + fuzz-coverage-trend | 200-denial stratified draw + FULL nightly crash list (census) | Platform/Security |
| patch-lag-histogram + cve-bins.csv | census of bins + 10 NOT-AFFECTED re-audited by 2nd reviewer | Security |
| hardening-evid.csv | census of .config asserts + 1 mitigation-cost re-measurement/SKU | Kernel/Security |
| lockscreen-evid.md | full 30-attempt sacrificial log (annual) + quarterly 12-wrong runs | QA |
| researcher-stats + wall-audit | census of researchers.md + CREDITS.md (link-liveness checked) | Security |
| supply-evid.md | per-class trigger log (unfired triggers = findings) | Security + area |

Sampling randomness: tests/review-sample.py --seed <year> (committed seed --
anyone can reproduce; hand-picked "representative" samples rejected by the tool).
No packs filed yet (TODO until first review cycle -- TODO is honest).
