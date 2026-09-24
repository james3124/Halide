# Flake triage runbook (ch.10 S11: flakes are bugs with a different hat).
# Triage within 48h of first quarantine nomination. Quarantine cap: 5 tests max
# per suite (6th request forces fixing-or-deleting an existing one first).

## 1. Reproduce-rate measurement
50 runs, dedicated runner, no code change. Command + rate + confidence recorded:
  SEED=<s> tests/repro-flake.sh <suite> 50
  Record log: logs/repro-flake-<suite>-seed<s>-<date>.log

## 2. Classify (fix the cause class, not the symptom)
| Class | Signature | Fix |
|---|---|---|
| timing-assumption | wait-dependent pass | poll-with-deadline (never raise sleep) |
| order-dependence | pass-alone fail-in-suite | fix the leak, not the order |
| resource-contention | shared-runner red | pin resources, record |
| real-product-race | product bug found | file P0/P1; test stays quarantined as net |

## 3. Quarantine entry (tests/quarantine.txt)
Format: <test-name> <BUG-id> <expiry-YYYY-MM-DD> <reason>
Expiry <=30 days. Still runs informationally. Counts as non-green in notes.

## 4. De-quarantine
Fix + 50-green streak (any fail resets). Soak-originated bugs additionally need
a 72h clean soak on the fixing RC (unit-test green alone is insufficient).

## 5. Infra-flake (exit 2) track
Label lab-infra with MTTR; 3 same-cause infra-flakes/month = lab P1 (fix the lab).
