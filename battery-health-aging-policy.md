# Battery Health and Aging Policy
**Parent: 10-test-cts-power-perf.md / 02-hardware-matrix.md**

## 1. Scope and goals
24 h standby + ≥4 h SOT within 20% of stock is the v1 contract; this policy keeps it true at month 24, not just day 1. Covers charge limits, cycle counting, gauge recal triggers, swelling response, and fleet battery reports. systemd-as-PID1: `halide-battery.service` (host, always on) owns limits/counters and exposes D-Bus `org.halide.Battery`; Android `BatteryService` mirrors via prop-bridge (single truth — container never estimates independently). AVB/LUKS2 unaffected; A/B OTA preserves counters across slots.

## 2. Charge limits
Default: stop at 100% with taper; Long-life mode (Settings → Battery): cap 80% (hysteresis resume at 75%), offered at first boot and after 50 cycles. Overnight adaptive: hold 80% until 60 min before alarm/wake-predict, then top up (predictor logged, user-overridable). Thermal derate: charge current halves at battery ≥40 °C, pauses ≥45 °C (resume ≤38 °C) — modem-call + charge concurrency tested. Required-battery OTA rule (≥30% + charger-or-override) reads the same gauge. Limits enforced in host charger driver + `halide-battery` policy, not in Android UI hints.

## 3. Cycle counting
Full-equivalent cycles (FEC): integrate charge mAh / design capacity per serial (`/var/lib/halide/battery.json`: design_mAh from `hw/<sku>`, cumulative_mAh, fec, first-use date). Partial charges sum fractionally (2× 50% = 1.0 FEC); counters survive factory reset? No — reset archives to `fleet` record then zeroes with operator-confirm id (wipe attestation line covers it). Dogfood gate: report mean FEC/month; >30 FEC/month flags heavy-use cohort for capacity audit.

## 4. Gauge recal triggers
Fuel-gauge (e.g. PMI8998 FG) drifts. Auto-recal when any of: (a) 90 days since last learn, (b) 60 FEC since learn, (c) jump >8% SoC on reboot, (d) shutdown at claimed >10% twice in 30 d. Recal = controlled 100%→shutdown→100% learn cycle with user consent prompt (night-time suggestion, charger required); log `LEARN <sku> <date> <old-cap> <new-cap>`. Lab quarterly: `halide-gauge-verify` (constant-load discharge vs coulomb count, error ≤5%). A/B OTA never clears learn data without re-learn flag.

## 5. Swelling response
Any visible back-cover lift, thickness delta >0.5 mm vs traveler baseline, or sudden capacity drop >15% after learn triggers SWELL protocol: (1) stop charging above 60% immediately (host-enforced), (2) quarantine from fleet nightly-charge carts, (3) support script captures `halide-log-collect --redact` + cycle/learn history + temp histogram, (4) RMA with swelling flag — never puncture/press/ship charged (ship ≤30% SoC per carrier rules). Single confirmed swell pages hardware owner; 2 in one lot freezes that lot (ch.11 risk input). Docs state limits plainly: swollen packs are replaced, not software-fixed.

## 6. Fleet battery reports
Monthly `fleet-battery <org>`: per-serial SoH% (= current full-charge mAh / design), FEC, learn age, limit-mode opt-in, temp-exposure hours >40 °C, swell flags. Thresholds: SoH <85% advise replacement at next service; <80% require replacement for on-call/carrier-verified roles. Reports contain no IMSI/IMEI; per-serial keyed by fleet inventory id. Charts feed the power dashboard alongside suspend-residency (>90% overnight) and `halide-power top` wakelock data.

## Verification
- [ ] 80% cap + hysteresis verified (charge stops 80±1%, resumes ≤75%); adaptive overnight holds then tops before alarm.
- [ ] FEC counters survive A/B OTA, increment fractionally, archive-on-wipe proven.
- [ ] Recal triggers fire on all four conditions; learn log present; lab discharge error ≤5%.
- [ ] Swell protocol drill passes: charge capped 60%, quarantine + RMA flag filed, lot-freeze rule acknowledged.
- [ ] Fleet report renders per-serial SoH/FEC/learn-age with 85%/80% actions and zero IMSI/IMEI.
