# wipe-aql.md — accepted quality level for wipe verification (ch.08 §28 normative sampling plan)
**Owner: QA + Security · Phase: factory — erase must be provable, not promised**

## What counts as wiped (per-unit verdict, ch.08 §21)

1. LUKS data keyslot erased (`cryptsetup erase`) — header verify-only preflight must match the wipe tool cipher.
2. `blkdiscard` userdata complete (`--verbose` trim-range log archived for 1% of lot).
3. New filesystem UUIDs written.
4. Verify (read-only, never re-erase during verify): LUKS header absent from userdata, **canary absent** (`CANARY-<random>` 32-hex written pre-wipe, searched post-wipe), attestation line in `misc` (`WIPE <sku> <ts> <operator-confirm-id>`).
5. Blind canary: QA injects a per-lot second canary in 1-in-20 units unknown to operators (blind-catch rate dashboarded).

## AQL (critical defect 0.25% — a unit leaving the line with recoverable plaintext is CRITICAL, not major)

| Lot size | Sample size | Accept | Reject |
|---|---|---|---|
| 281–500 | 50 | 0 | ≥1 |
| 51–90 | 13 | 0 | ≥1 |
| ≤50 | 100% | 0 | ≥1 |

Inspection Level II, lot = one shift-one-station. **Continuous-line alternative:** rolling 200-unit window, halt on 2 fails in window (erase failures cluster by station/tooling, not randomly).

## Rejected lot

100% re-verify (read-only) + root-cause before restart (`security/wipe-lot-<id>.md`). `WIPE-VERIFY-FAIL` units quarantined; rework requires a new canary cycle + new attestation line linked `retry-of:`.

Expected: lot manifest `factory/wipe-lot-<id>.csv` passes `tests/wipe-stats.py` arithmetic (sample-size vs table, blind coverage) before QA countersign.

Fail action: half-verified device never ships back as "clean" (RMA rule).
