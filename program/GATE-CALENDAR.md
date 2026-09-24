# GATE-CALENDAR.md — gate dates per quarter (ch.00 phase gates + ch.11 §15 calendar)
**Owner: Program + Arch (guardianship ch.11 ladder) · Phase: all — moved twice escalates per ch.01 §27**

## 2026 Q3

| Date | Gate | SKU | Owner sign pair |
|---|---|---|---|
| 2026-08-14 | Gate 1-2 boot-to-shell | REF-A | BSP + QA — **PASS** (record `gates/1-2-20260814-REF-A`) |
| 2026-09-30 | Gate 2-3 entry prep (input matrix calibrated + panel.json measured) | REF-A | Graphics + QA |

## 2026 Q4

| Date | Gate | SKU | Owner sign pair |
|---|---|---|---|
| 2026-10-30 | Gate 2-3 GUI + 1 app | REF-A | Graphics + Platform + QA |
| 2026-12-15 | Quarterly gate review + calibration expiry sweep (ch.02 S13) | all | QA + Arch |

## 2027 Q1

| Date | Gate | SKU | Owner sign pair |
|---|---|---|---|
| 2027-02-28 | Gate 3-release entry (Phase-3a/b/c sheets green) | REF-A | QA + Security |

## 2027 Q2

| Date | Gate | SKU | Owner sign pair |
|---|---|---|---|
| 2027-04-30 | Gate 3-release daily-driver | REF-A | QA + Security + Arch + Program |
| 2027-06-30 | REF-B own 3-release sign (no inherited blessings) | REF-B | same quorum |

## Rules

- No verbal gates, ever (ch.00). Gate record + JSON sidecar committed before the sign counts.
- Failed gate = dated root-cause week + re-run scheduled in the gate record.
- REF-B never inherits REF-A signers or build IDs.

Expected: calendar reviewed at every release train; next gate within 90 days always has a named owner.
