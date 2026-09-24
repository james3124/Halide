# battery.md - REF-A battery + gauge + charger report (ch.03 S13/S35, app-03A)
# Owner: BSP/Power. Gauge IC via qcom-spmi ADC channels + gauge node
# (max17040-class) with calibration; charger via qcom,qpnp-smb.
# WHY this file (S13): report full-charge-capacity vs design capacity here,
# with temperature compensation noted (appendix-03A quirk 3: gauge reads ~3%
# low under 15C - compensation table lives in 80-battery.dtso comment + source).

## Cells / design
DESIGN_CAPACITY_MAH=3300
# WHY (S13): full-charge-capacity vs design capacity reported per release.

## Gauge calibration (per release rows; SEED pending HW run)
| Date | FCC mAh | Design mAh | FCC/design % | Temp C | Notes |
|---|---|---|---|---|---|
| PENDING | PENDING | 3300 | PENDING | 25 | seed - first gauge dump lands here |
# Quirk: subtract ~3% below 15C before judging (compensation table in DT comment).

## Charger detection log (S35 - type line MANDATORY in battery reports)
# /sys/class/power_supply/usb/type + current-max negotiated per charger:
# SDP / CDP / DCP / HVDCP distinguish. Wrong type = slow-charge complaints
# with no logs.
| Date | Charger | type | current-max uA | Notes |
|---|---|---|---|---|
| PENDING | stock 18W | PENDING | PENDING | seed |

## ADC channels (qcom-spmi; provenance per S13)
BATT_ID_ADC=PENDING-channel
BATT_TEMP_ADC=PENDING-channel
VBATT_ADC=PENDING-channel

## Verification
- [ ] FCC/design reported per release with temperature noted.
- [ ] Charger type line present for each tested charger.
- [ ] Gauge compensation table sourced in 80-battery.dtso comment.
