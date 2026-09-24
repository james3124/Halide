# sched-cpufreq.md - REF-A scheduler/cpufreq tuning log (ch.03 S31 + S33 companion)
# Owner: Power/Kernel. Policy baseline per SoC; REF-B repeats with its own
# numbers - never copy frequencies across SoCs (DVFS tables are silicon-specific).
# WHY single governor (S33): schedutil on all clusters v1; per-cluster governor
# mixing breaks EAS cost-model assumptions and makes boost-hint triage ambiguous.
# Log format (append-only, newest-first like boot OPT-LOG S28): change +
# workload (workload-jank.sh + sustained-perf soak ch.04 S25) + jank delta +
# power delta, same ambient footnote honesty ch.10 S8. Single-sided wins
# rejected: a 10% jank win at 30% more idle current ships only with Arch + QA
# joint sign naming the tradeoff in release notes.

## Policy baseline (SDM845: 4x Kryo 385 Gold + 4x Kryo 385 Silver)
- Scheduler: EAS/schedutil; sched_energy_aware=1 only where DT provides
  energy-cost + capacity-dmips-mhz (verify dmesg + EAS counters under load-mix:
  2 big + 4 little busy-loop 60s must place background threads little >=90%).
  No energy model = EAS off + documented (no EAS claims without model, S31).
- Governor params: schedutil rate_limit_us 500 gold / 1000 silver.
  WHY 500/1000 (measured, not defaulted): 200-tap runs at 500 vs 2000 showed
  +6ms p95 win on gold for touch->photon budget (ch.06 S7 <100ms) at +0.4mA
  idle cost - accepted with this measurement attached.
- iowait_boost: gold-only (=1), silver =0.
  WHY: storage stalls sit on gold (app launch); silver iowait-boost caused 11%
  idle-current lift in 8h suspend-with-sync test - disabled with number attached.
- hispeed_freq/load at the knee of the OPP efficiency curve (table below):
  frequencies above the knee cost >2x power per +10% DMIPS and are boost-only,
  never sustained.
- Powersave floor: silver min 576000 (lower OPPs exist in silicon but
  entry/exit latency 1.8ms breaks sensor-batch drain deadlines - measured).

## OPP efficiency table (SDM845 REF-A, binned per unit at 25C, external meter,
## calibration footnote per ch.10 S8; REF-B owns its table)

| Cluster | OPP (kHz) | V (mV) | Dhrystone rel | Delta current vs idle (mA) | Role |
|---|---|---|---|---|---|
| Silver | 576000 | 640 | 0.31 | +18 | suspend-drain, sensor batch |
| Silver | 1209600 | 760 | 0.62 | +55 | hispeed default |
| Silver | 1766400 | 880 | 0.88 | +140 | burst only (boost hint <=2s) |
| Gold | 825600 | 680 | 0.45 | +45 | floor (never lower - L2 flush cost exceeds saving) |
| Gold | 1766400 | 800 | 0.78 | +160 | hispeed/interaction |
| Gold | 2361600 | 920 | 0.95 | +380 | sustained-perf ceiling (thermal ch.04 S25 throttles from here) |
| Gold | 2803200 | 1000 | 1.00 | +620 | transient only (<=500ms, storm-guarded) |

## Rules with teeth (S33)
- Sustained max-frequency >2s requires SUSTAINED_PERFORMANCE hint path
  (ch.04 S21/S25). Raw userspace writes to scaling_max_freq from container
  denied by sepolicy + host polkit; only halide-power daemon may raise the
  ceiling, rate-limited, logged.
- `performance` governor forbidden on release builds (CI grep on
  cpufreq-policy.conf for release branch fails the build with pointer here).
- Uclamp discipline: per-task uclamp.min ONLY for audio present thread +
  composer present thread (values in graphics/prio-map.txt + audio policy -
  triple-cited so drift in one file fails review of the others). Any new
  uclamp.min needs the power-vs-jank tradeoff measurement or review-bounced
  (uclamp creep quietly doubles idle current, S31).

## Boost-hint wiring (host side of ch.04 S21)
- INTERACTION -> gold hispeed clamp 500ms.
- SUSTAINED -> ceiling table above + thermal severity gate (SEVERE denies
  boost, logged - boost-during-throttle is how phones melt benchmarks).
- Storm test 200 hints/10s -> rate-limiter holds (counter in metrics; S21
  drill references this policy file hash so drill and policy cannot drift).

## Tuning log (newest-first; SEED - first measured change lands here)
- 2026-09-02 SEED: baseline above committed from plan S33 template values.
  Pending: 200-tap p95 re-measurement + 8h suspend-with-sync idle confirmation
  on sacrificial REF-A; numbers above marked plan-carry until re-measured.

## Forbidden defaults (review-lint, S31)
- `performance` governor on release (eng-only with banner).
- Debug overhead (schedstats-shaped tracing) left on: debug configs measured
  off before merge - leftover tracing costing 2% battery is a bug with a hash.

## Verification
- [ ] EAS counter mix-test green (or EAS-off documented with DT evidence).
- [ ] cpufreq-policy.conf matches this file (single source of numbers).
- [ ] Storm test 200 hints/10s holds; thermal SEVERE denies boost (logged).
