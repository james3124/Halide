# Noise floors template (power-regression-bisect S4: floors reviewed quarterly
# from 90-day variance). Copy to power/floors-<quarter>.md (e.g. floors-2026Q4).
# Tuning order: increase reps (2->3) before widening thresholds; split LTE by
# RSRP bin before touching thresholds. Target: <1 false bisect per month.

| Tuning action | Before | After | False-alarms before/after |
|---|---|---|---|
| TODO (reps 2->3 / RSRP binning / re-baseline) | TODO | TODO | TODO |

Current floors (must match tests/soak-alerts.conf where overlapping):
suspend-8h: +15% mA or -5pp residency, noise +-5%
screen-off-idle: +12% or -4pp, noise +-4%
video-LTE-GNSS-active: +10%, noise +-6%
Re-baseline events (WA change / meter recal / new battery - old median archived,
never overwritten): TODO (date + reason + sign-off)
