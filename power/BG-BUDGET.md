# BG-BUDGET.md — background-power budget (ch.10 §8/§17 discipline)
**Owner: power bring-up · Phase: 3 — single-sided wins rejected; every budget row has a measurement path**

## App-class budget (per-device-day, calibrated unit + golden accessories per ch.02 §21)

| App class | wakelock budget | alarms/day | Notes |
|---|---|---|---|
| System (systemd/bridges/lmkd) | ≤10s/h held | n/a (systemd timers) | bridge polling coalesced; PSI not polls (ch.05 §25) |
| Modem (MM + ril-bridge) | signal poll 10s idle / 2s in-call | n/a | DRX-preserved; power tradeoff recorded (ch.07 §9) |
| Instant messengers | ≤60s/day aggregate | ≤96 (15-min floor) | FCM-less push = alarm+sync window |
| Social/feed sync | ≤120s/day aggregate | ≤48 (30-min floor) | background data opt-out honored |
| Location (background) | 0 continuous | ≤24 | foreground-only GNSS unless user grants always |
| Alarms/clock | ≤2s/event | user-set | alarm bootreason pinned (ch.03 §37 vocabulary) |
| Media/spotify-class | screen-off ≤15min/day | 0 | suspend residency target relaxed only while streaming (ch.05 §21) |

## Gates

- Overnight suspend residency >90% (power/refa/budget.md); 24h standby drop ≤10% envelope.
- Wakeup audit after every budget MR: top-10 `wakeup_sources` diffed vs baseline — new storm = budget busted.
- Attribution: every persistent top-10 consumer UID named in the energy model (`power/REF-A/energy-model.csv`); mystery UIDs are wakelocks in disguise (ch.10 §17).

Expected: `halide-power top --record` overnight shows suspend residency >90% and no budget-row consumer above its wakelock line.

Fail action: capture batterystats + kernel wakeups, file power bug with budget-row id.
