# Battery health tracking template (battery-health-aging-policy: 24h standby +
# >=4h SOT within 20% of stock must hold at month 24, not just day 1).
# Copy per-SKU sheets from this template. Owner: halide-battery.service (host,
# always on); Android BatteryService mirrors via prop-bridge (single truth).
# Counters in /var/lib/halide/battery.json; survive A/B OTA; archive-on-wipe.

## Charge limits
Long-life-80pct-cap: TODO (verified stop 80+-1%, resume <=75%)
Overnight-adaptive: TODO (hold 80% until 60min before alarm, then top up)
Thermal-derate: TODO (halve at >=40C, pause >=45C, resume <=38C)

## Cycle counting (FEC = charge mAh / design mAh per serial)
Design-mAh: TODO-measured (from hw/<sku>)
Cumulative-mAh: TODO-measured
FEC: TODO-measured
First-use-date: TODO-measured
Mean-FEC-per-month (dogfood gate, >30 flags heavy-use cohort): TODO-measured

## Gauge recal (fuel-gauge drifts; auto-recal on any trigger)
Last-learn-date: TODO-measured
FEC-since-learn: TODO-measured (trigger at 60)
90-day-trigger: TODO (fired y/n + date)
Reboot-jump->8pct-trigger: TODO (fired y/n + date)
Shutdown-above-10pct-x2-trigger: TODO (fired y/n + date)
Learn-log: LEARN <sku> <date> <old-cap> <new-cap>: TODO-measured
Lab-discharge-error (<=5%): TODO-measured

## Swelling response (SWELL protocol)
Back-cover-lift-or-0.5mm-delta-or-15pct-capacity-drop: TODO (y/n)
Charge-capped-60pct: TODO (host-enforced y/n)
Fleet-quarantine: TODO (y/n)
RMA-swelling-flag: TODO (ship <=30% SoC, never puncture/press/ship charged)
Lot-freeze (2 in one lot): TODO (y/n + ch.11 risk input)

## Fleet report (monthly, per-serial fleet id - no IMSI/IMEI)
SoH-pct (full-charge / design): TODO-measured (advise replace <85%, require <80%)
Temp-exposure-hours->40C: TODO-measured
Limit-mode-opt-in: TODO (y/n)
