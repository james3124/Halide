# Power budget (text-only)
- Suspend residency gate: >90% over 1 h idle with radio on.
- Standby gate: 24 h standby drop <= 10% stub, refine per battery.
- Measure: power_stats + battery historian only; no lab PSU data here.
- Ref: graphics/refa/limits.conf fps/layers affect rail.
- Ref: thermal/refa/trip-points.conf charging throttle coupling.
- Fail action: capture dumpsys + kernel wakeups, file power bug.
- No binaries; traces outside repo. Owner: power bring-up; re-run after DT changes.
