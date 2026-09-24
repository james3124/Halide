# maintainers.md — roster, roles, history (ch.11 §19 governance; review routing per repo-layout CODEOWNERS)
**Owner: Program + Arch · Phase: all — demotions logged with dates + reason class (no silent permission rot)**

## Active roster

| Name | Role | Areas (CODEOWNERS routing) | Gate sign authority | Backup |
|---|---|---|---|---|
| ana | Maintainer | kernel/, hw/, devices | BSP gates | bora |
| ken | Maintainer | tests/, QA evidence, logs/ | QA gates | chen |
| dana | Maintainer | debian/, bridges/, program/ | Platform gates | efu |
| gita | Maintainer | security/, keys/ | Security co-sign | hana |
| ivan | Arch (rotating, quarterly) | cross-cutting, ADRs, gate-calendar | tie-break + co-sign | rotates |

## Review routing (matches repo-layout §2 CODEOWNERS excerpt)

- `security/ keys/` → security + arch (2-person: +area owner)
- `compat/ support/ program/` → program (docs review: owner + one user-voice)
- Area reviewers need ≥8 MRs + ≥15 checklist reviews + ≥1 gate-evidence artifact (ch.11 §19 promotion bar).

## History (append-only)

| date | name | event | reason class |
|---|---|---|---|
| 2026-08-14 | ana, ken | signed gate 1-2 REF-A | evidence: gates/1-2-20260814-REF-A |
| (none yet) | — | demotion/promotion | inactivity / gate-breach / conduct / promotion |

## Rules

- Inactivity (no merged MR or review in 6 months) → emeritus, restorable by one quarter of re-activity.
- Gate breach (merged red-CI, testkey bypass, APN clobber) → immediate suspension + retro within 7 days.
- Every area keeps a named backup with ≥1 merged MR in the trailing quarter (ch.11 §17 backfill rule).

Expected: annual maintainer roll-call confirms roster + backups; stale entries get STALE- prefix.
