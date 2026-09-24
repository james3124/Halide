# QA sign-off <ver> (ch.10 S16: the signature page - names, not "QA approved").
# Commit pre-rollout-past-10%. Every evidence link resolves to a committed
# artifact, not a chat message. Zero-exception releases state "none" explicitly.
# Dissent ships in internal release notes + forces Arch review.

## Per-gate evidence links
| Gate | Evidence path | Verdict |
|---|---|---|
| dogfood (counts + dates) | qa/dogfood-<ver>.csv | TODO |
| CTS/VTS XML | cts-results/<date>/summary.md + XML | TODO |
| power sheets | power/<sku>/results-<ver>.md | TODO |
| soak report | logs/soak-72h-<date>.csv + slope verdict | TODO |
| attack-subset log | TODO (attack-test-plan row) | TODO |
| lockscreen-5 record | logs/lockscreen5-<date>.csv | TODO |
| crypto-erase + relock + rollback drills | TODO (dates) | TODO |

## Exceptions granted
| What | Why | Compensating control | Expiry |
|---|---|---|---|
| (none) | - | - | - |

## Dissent
| Name | Reason | Arch review date |
|---|---|---|
| (none) | - | - |

## Signatures (same names as ch.00 gate rules)
| Role | Name | Timestamp |
|---|---|---|
| QA lead | TODO | TODO |
| Security | TODO | TODO |
| Arch | TODO | TODO |
| Program | TODO | TODO |

## Post-release 48h watch roster (human eyes on rollback-rate + crash telemetry)
| Stage | Watcher | Handoff note |
|---|---|---|
| 1% | TODO | TODO |
| 10% | TODO | TODO |
