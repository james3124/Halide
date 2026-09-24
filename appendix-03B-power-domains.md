# Appendix 03-B — Power Domains, Interconnect Votes & Idle-Current Budget
**Parent: ch.03 §§13,17 · Per-SKU numbers in `power/<sku>/rails.md` · Method: measure every claim**

## 1. Domain map (SDM845 shape — adapt per SoC, cite stock dump per line)

`rpmh` ARC/rails → `genpd` domains: `mdss_gdsc` (display), `cam_cc`/`camss_gdsc` (camera), `venus_gdsc` (video), `adsp/cdsp/mpss` PAS domains (DSP+modem), `gcc_usb` (USB), `lpass` (audio). Each domain row: owner driver, `power_on` latency measured (µs, `trace-cmd` power events), parent rail, collapse-allowed-in-suspend (yes/no + why — modem domain never collapses with registered SIM: re-attach cost 8–20s measured, documented once so nobody "optimizes" it later).

## 2. Interconnect (`icc`) vote table (display/camera/modem concurrency without underrun)

Paths: `display→ddr`, `camera→ddr`, `venus→ddr`, `modem→ddr`, `cpu→llcc`. Votes per use-case (idle / UI-scroll / camera-preview / camera+display+iperf-max): kB/s values from vendor `bwmon` traces + our `icc` debugfs reads (both recorded — vendor tables are starting points, our silicon температурой measure is truth). Underrun signature table: `mdp` underrun counter + `camss` overflow + iperf dip coinciding = vote bug (not composer bug — ch.06 §9 differential diagnosis references this). Vote changes land with before/after `rpm_stats` residency + current numbers (votes cost power — every vote increase shows its mA receipt).

## 3. Idle-current budget (the mA balance sheet — sums to the overnight gate)

Target decomposition example (REF-A, SIM+Wi-Fi on, display off — replace with measured): SoC-deep-sleep 3mA + DRAM-refresh 4mA + modem-DRX 6mA + Wi-Fi-DTIM10 2mA + sensors-batch 1mA + PMIC-quiescent 2mA + leakage-margin 4mA = 22mA budget → 8h ≈ 176mAh ≈ 5% of 3300mAh (the math shown so gate misses localize: over by 10mA? read the rows — modem-DRX row red means ch.07 DRX tuning, display-row red means PSR/panel, sensor-row red means batch config). Each row has owner + measurement command (`power/<sku>/rails.md` procedures re-runnable). Budget reviewed when any row changes >20% (auto-flag from nightly `rpm_stats` uploads).

## Verification

- [ ] Domain collapse table + vote table + mA budget all measured (no datasheet-only rows); underrun/cuprit attribution demonstrated once live.
