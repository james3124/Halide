# RUNBOOK - Health (IHealth AIDL) - ch.04 S21
# Owner: @platform-lead - Backup: @android-lead - Last drill: TODO (fill at
# bring-up; undrilled runbooks expire after 90 days and block the gate).
# Service: android.hardware.health IHealth, instance default, transport aidl.
# Host peer: upower/sysfs single source (Android never reads fuel-gauge
# directly - neverallow S14.3). Model: power/<sku>/battery-curve.json model_vN.

## 60-second smoke
lxc-attach -n android -- dumpsys health | grep -Ei 'capacity|current|voltage|temp' | head -10
cat /sys/class/power_supply/battery/capacity /sys/class/power_supply/battery/current_now
# Expect: agreement +/-2% capacity, +/-50mA current after 30s settle (wider = P1,
# dual-read paths split - fixed in curve file with version bump, never UI fudge).

## Failure ladder
1. Disagreement -> model offset in battery-curve.json (bump model_vN + loop CSV).
2. Missed charger events -> plug/unplug 10x must each emit a HAL event.
3. No shutdown-intent at 5% -> host owns shutdown call (Android suggests,
# host decides - never inverted).

## Drill (quarterly, backup performs it - S28)
Charger plug/unplug 10x (zero missed) + low-battery 5% shutdown-intent path.
