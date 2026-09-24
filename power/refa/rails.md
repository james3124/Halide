# rails.md - REF-A power domains, interconnect votes, idle-current budget
# (appendix-03B; per-SKU numbers live HERE. Method: measure every claim.)
# Owner: Power/BSP. Cite stock dump per line (S13 provenance rule).

## 1. Domain map (SDM845 shape)
# Columns: domain | owner driver | power_on latency us (trace-cmd) | parent rail | collapse-in-suspend | why
# modem domain NEVER collapses with registered SIM: re-attach cost 8-20s measured (app-03B).
mdss_gdsc | msm-drm | PENDING-us | vregibaba-rail-stock | yes-display-off | display votes gate panel power (S13 icc companion)
cam_cc camss_gdsc | camss | PENDING-us | camera-rail-stock | yes-idle | preview vote only while streaming
venus_gdsc | venus-v4l2 | PENDING-us | video-rail-stock | yes-idle | transcode sessions hold explicit vote
adsp cdsp mpss PAS | qcom-q6v5-pas | PENDING-us | cx-mx-stock | mpss-NO-with-SIM | re-attach 8-20s; adsp/cdsp collapse ok screen-off-music keeps lpass
gcc_usb | dwc3-qcom | PENDING-us | usb-rail-stock | yes-suspend | autosuspend policy S35; wakeup only gesture/charger
lpass | lpass-audio | PENDING-us | audio-rail-stock | yes-except-offload-playback | offload keeps vote (cpuidle music row S38)

## 2. Interconnect (icc) vote table kB/s (vendor bwmon start, OUR silicon truth)
| Path | idle | UI-scroll | camera-preview | camera+display+iperf-max | source |
|---|---|---|---|---|---|
| display->ddr | PENDING | PENDING | PENDING | PENDING | bwmon+icc-debugfs seed |
| camera->ddr | PENDING | PENDING | PENDING | PENDING | bwmon+icc-debugfs seed |
| venus->ddr | PENDING | PENDING | PENDING | PENDING | bwmon+icc-debugfs seed |
| modem->ddr | PENDING | PENDING | PENDING | PENDING | bwmon+icc-debugfs seed |
| cpu->llcc | PENDING | PENDING | PENDING | PENDING | bwmon+icc-debugfs seed |
# Underrun signatures: mdp underrun counter + camss overflow + iperf dip
# coinciding = VOTE bug not composer bug (ch.06 S9 differential). Vote changes
# land with before/after rpm_stats residency + current numbers (votes cost
# power - every increase shows its mA receipt).

## 3. Idle-current budget (mA balance sheet; sums to the overnight gate)
# REF-A SIM+Wi-Fi on display off (replace with measured; math shown so misses localize).
| Row | mA | Owner | Measurement |
|---|---|---|---|
| SoC-deep-sleep | 3 | Power | cpuidle residency S38 + meter |
| DRAM-refresh | 4 | BSP | meter delta suspend-vs-off |
| modem-DRX | 6 | Modem/ch.07 | DRX tuning; red row -> ch.07 |
| Wi-Fi-DTIM10 | 2 | Net | dtim10 confirm + meter |
| sensors-batch | 1 | Sensors | batch 50Hz residency row S38 |
| PMIC-quiescent | 2 | Power | rail baseline hw/refa/regulator-baseline.txt |
| leakage-margin | 4 | Power | residual |
| TOTAL budget | 22 | - | 8h ~= 176mAh ~= 5% of 3300mAh |
# Budget reviewed when any row changes >20% (auto-flag from nightly rpm_stats).

## Verification
- [ ] All domain/vote/budget rows measured (no datasheet-only rows).
- [ ] Underrun attribution demonstrated once live (vote vs composer).
