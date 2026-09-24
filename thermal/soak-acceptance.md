# Thermal soak acceptance (ch.10 S28: soak heat is a release gate).
# Rhythm: 30-min video-over-LTE + 10-min camera burst + 15-min cooldown idle,
# 3 runs per SKU on the labeled gating unit + 1 cross-unit sanity run
# (cross-unit delta >3C at same probe = INVALID-RERUN, never averaged away).
# Footnotes per run (ch.10 S12): unit, firmware SHAs, ambient 23+-2C, 200 nits.
# NEVER invent numbers: unmeasured cells stay TODO-measured.

| Scenario (gating unless noted) | Skin limit | SoC/battery probe | Throttling band | Result |
|---|---|---|---|---|
| 30-min video + LTE | <=45C palm-center <=43C top-edge | SoC <=85C battery <=40C | >=70% clocks thru min 25 (dips to 60% <=60s x2 max) | TODO-measured |
| 10-min camera burst | <=45C ring <=44C palm | SoC <=88C peak battery <=40C | >=70% avg (dip to 55% <=30s x1) | TODO-measured |
| 30-min voice call earpiece | <=41C earpiece <=40C palm | SoC <=75C battery <=38C | >=85% clocks, no underrun-linked drop | TODO-measured |
| 30-min hotspot 1 client 100MB | <=44C palm | SoC <=85C battery <=40C | >=70% clocks, DRX not collapsed >80% | TODO-measured |
| Cooldown 15-min screen-off LTE idle | <35C palm by min 10 | SoC drop >=15C in 10min | >=90% idle-opp within 5min | TODO-measured |
| Urban-canyon repeat (URBAN, informational) | report-only | report-only | report-only | TODO-measured |

Fail mapping: hard-throttle <70% before min 20 = P0; skin >45C = P0;
battery >40C = P1 + battery-health-aging-policy review; thermal abort = P0;
earpiece >41C = P1; any thermal shutdown = P0; still >35C at min 15 = P1
(heat-trap dig per ch.10 S25 with frozen wakeup_sources + power tail).
Rows land in power/<sku>/results.md and release-compare PERF/SOAK rows before
rollout passes 10% (missing rows block sign-off like any absent evidence_path).
