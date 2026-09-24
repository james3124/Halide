# cpuidle-governor.md - REF-A cpuidle governor + idle-state table (ch.03 S38)
# Owner: Kernel/BSP + Power. REF-B repeats with its own silicon numbers -
# never copy residency/latency across SoCs.
# WHY menu (S38): ladder forbidden on arm64 (selection hysteresis wrong for
# clustered power domains). menu + teo comparison committed here; teo stays
# eng-experiment until 8h idle A/B proves parity.
# DT source: cpu-idle-states + domain-idle-states nodes with provenance
# comments per S13; any state without exit-latency-us + min-residency-us +
# local-timer-stop flag is review-fail.

GOVERNOR=menu
# teo status: eng experiment only (no 8h A/B yet - SEED).

## Idle-state table (SDM845: 4x Kryo 385 Gold + 4x Kryo 385 Silver)

| State | Cluster | HW meaning | Exit-lat (us) | Min-residency (us) | local-timer-stop | Role |
|---|---|---|---|---|---|---|
| WFI | Silver/Gold per-CPU | clock-gated, L1 retained | 2 / 2 | 5 / 5 | 0 | syscall-idle, irq-heavy phases (touch poll) |
| C1 (cpu-sleep-0) | Silver | L1 off, L2 retained, timer running | 45 | 200 | 0 | short gaps (composer vsync wait, 16ms cadence) |
| C1 (cpu-sleep-0) | Gold | L1 off, L2 retained, timer running | 60 | 250 | 0 | same, gold ramp headroom for interaction |
| C2 (cluster-sleep-0) | Silver cluster | L2 off, CCI still on, timer stopped | 450 | 1200 | 1 | suspend-drain, sensor batch gaps |
| C2 (cluster-sleep-0) | Gold cluster | L2 off, CCI still on, timer stopped | 650 | 1800 | 1 | deep idle between interaction bursts |
| C3 (apss-sleep / XO shutdown) | both (system) | APSS + XO off, RPMH holds votes, modem DRX independent | 2500 | 8000 | 1 | airplane-idle / screen-off music / mem suspend entry |

## Residency targets (external-meter truth + sysfs counters, ambient footnote
## per ch.10 S8; 8h airplane-idle medians on sacrificial REF-A, charger
## detached, SIM present, Wi-Fi off)

| Scenario | Silver deepest (C2+C3) | Gold deepest | WFI ceiling | Meter idle (mA) |
|---|---|---|---|---|
| airplane-idle screen-off 8h | >=85% | >=80% | <=5% | <=8 (REF-A 4GB) |
| screen-off + sensor batch 50Hz 8h | >=70% | >=65% | <=10% | <=14 |
| screen-off music (DSP offload) 4h | >=60% | >=55% (gold mostly collapsed) | <=12% | <=28 |
| voice call (modem DRX, S33 call profile) | >=40% (blocked variant) | >=30% | <=20% | <=95 |

## Measurement runbook (host shell, no container dependency - S38)
1. `cat /sys/devices/system/cpu/cpuidle/current_governor_ro` (expect menu);
   `cpupower idle-info`; per-CPU state name/desc dumps.
2. Latency/residency as the kernel sees them (must match DT table above).
3. Snapshot counters, soak (3600 short-gate; 28800 release gate), delta via
   `python3 scripts/cpuidle-residency.py --before ... --after ... --format md`
   (exits nonzero on target miss with named state).
4. Cross-check wakeup audit (S8/S17) + clk_summary XO state in the same run.
Expected: 3 states per CPU, none disabled except call-profile override
(`CALL-PROFILE active: silver-C2 blocked`); residency PASS/FAIL per scenario;
wakeup top-5 within +-10% of baseline (new stormer + residency miss = ONE bug
with both logs, not two).

## Troubleshooting ladder (residency miss -> cause in order, no skipping, S38)
1. disable flags (call-profile left armed? halide-cpuidle-apply idempotency bug).
2. Wakeup storm (stormer >100/s explains any miss - fix storm first).
3. Timer tick (NO_HZ misconfig or local-timer-stop=0 state absorbing residency).
4. Clk vote held (XO never off - RPMH vote leak; pm_genpd + interconnect dumps).
5. Governor selection (ftrace cpuidle 60s; menu predicted-shallow pattern).
6. Thermal/freq clamp (hot idle never enters C3 - ambient note decides).
Each step logs to logs/cpuidle-triage-<date>.txt; FAIL without triage log is
returned by QA as not actionable.

## Arch-timer erratum note (S38 knob table)
SDM845 timer broadcast misroute adds ~300 wakes/h (measured once); watch
`timer_migration` + wakes/h alongside residency. broadcast-timer +
local-timer-stop mistags break broadcast wakeups (dmesg broadcast clean + residency).

## Verification
- [ ] current_governor_ro == menu; idle-info matches DT table.
- [ ] 8h airplane-idle residency + meter inside targets (or triage log + BUG).
- [ ] Call soak gap counter 0 with profile armed/disarmed correctly.
