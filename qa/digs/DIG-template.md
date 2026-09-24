# DIG <id> (ch.10 S25: long-tail bug archaeology - one page, same template).
# Frozen evidence lives in this dir (FREEZE.json + tails); never paste dumps here.
# Redacted logs only; raw bundles stay in quarantine-store with expiry.

## Symptom
TODO (one line + first-seen build/date)

## Evidence pointers
- FREEZE.json (trigger, UTC, MANIFEST SHA, retention 90 days)
- dmesg-tail.txt / wakeup-sources.txt / power-tail.txt / pstore.txt

## Timeline (UTC)
| When | What |
|---|---|
| TODO build | TODO |
| TODO soak-day | TODO |
| TODO trigger-time | TODO |

## Hypotheses ranked (<=3, each with a disproving test)
1. TODO (disprove by: tests/repro-flake.sh <suite> <seed>, TODO runs)
2. TODO (disprove by: TODO)
3. TODO (disprove by: TODO)

## Bisect status
MANIFEST delta range: TODO (AOSP rev / kernel fragment / overlay list)
Soak-parameter bisect: TODO (halve rhythm: hourly->2-hourly; slope moves = workload, stays = clock)

## Verdict (one)
NEW-BUG <id> / DUPE <id> / LAB-INFRA <id> / NEEDS-LONGER-SOAK (with booking)

## Prevention item (a dig without one repeats - rejected in review)
Updates one of: tests/soak-alerts.conf / tests/quarantine.txt annotation /
power/<sku>/results.md footnote / qa/compare-* methodology. Item: TODO
