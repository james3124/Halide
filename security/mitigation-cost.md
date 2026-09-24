# mitigation-cost.md — kernel/crypto mitigation perf-delta table (ch.08 §16/§32 — cost reviewed beside benefit)
**Owner: Security + Kernel · Phase: per-LTS bump — total boot tax visible in one sheet**

Template per LTS bump / KDF ceremony; fill with measured numbers (two-sided: security win AND cost, never one-sided wins — ch.03 §31 single-sided rule).

| Mitigation | Config | Boot time delta (ms) | Idle power delta (mW) | RAM delta (MB) | Micro-bench (lmbench/cryptsetup) | Verdict |
|---|---|---|---|---|---|---|
| HARDENED_USERCOPY | `=y` | TODO-measure | TODO | 0 | TODO | — |
| FORTIFY_SOURCE | `=y` | TODO | TODO | 0 | TODO | — |
| STACKPROTECTOR_STRONG | `=y` | TODO | TODO | 0 | TODO | — |
| RANDOMIZE_BASE (KASLR) | `=y` | TODO | TODO | 0 | TODO | — |
| INIT_ON_ALLOC_DEFAULT_ON | `=y` | TODO | TODO | TODO | TODO | — |
| SLUB_DEBUG_ON | `=n` (release) | 0 (kept off) | 0 | saved | — | PASS by design |
| Argon2id m=1024/t=4/p=2 | LUKS2 (REF-A) | unlock p50 1400 / p95 2600 ms | — | — | cryptsetup benchmark row | within SLO ch.08 §32 |

## Rules

- Every mitigation stays on unless a measured regression is filed + reviewed (defense-in-depth default, ch.08 §16).
- Boot-time tax reviewed beside KDF cost per rotation ceremony (ch.08 §32 (b) row).
- Verdict column filled only with measured ambient-footnoted numbers (ch.10 §8 honesty).

Expected: table complete for the shipped LTS; `INIT_ON_ALLOC` boot cost measured once per LTS and recorded.

Fail action: missing measurement = bump blocked until measured, not waived.
