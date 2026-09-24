# Power Result Sheet Template + Calibration Discipline
**Parent: ch.10 §8, ch.02 §6 · One file per SKU per release: `power/<sku>/results-<ver>.md`**

## 1. Calibration header (mandatory — uncalibrated numbers are rejected)

```
Unit: HALIDE-A1 (sacrificial, battery-eliminator) + HALIDE-A2 (dogfood, USB-PD meter)
Meter: <model + fw> @1Hz, offset vs 34401A reference: +2.3% (cal 2026-05-01, due 2026-11-01)
Ambient: 23±2C chamber-log attached: YES (csv)
Cell/band: <cell-id BAND cal-day> or shield+callbox profile <name>
Brightness: 200 nits (lux-meter serial <n>, panel PWM <freq>)
Firmware: modem <ver>, wlan <ver> (SHAs in BLOBS)
```

## 2. Results table (median of 3 + stock oracle same conditions)

| Scenario | HALIDE med | Stock med | Delta | Gate | Verdict |
|---|---|---|---|---|---|
| Overnight 8h suspend (mA mean) | _ | _ | _% | ≤2× stock | _ |
| Browsing 1h SOT (mA) | _ | _ | _% | report | _ |
| Voice 30min (mA) | _ | _ | _% | report | _ |
| Hotspot 30min (MB/mA) | _/_ | _/_ | _% | report | _ |
| Video 720p 30min (mA) | _ | _ | _% | report | _ |
| Camera burst 10min (peak skin °C) | _ | _ | — | ≤45°C | _ |
| Suspend residency % (rpm_stats) | _ | ~_ | — | >90% overnight | _ |

Top-10 `wakeup_sources` diff attached (halide vs stock-approximate where measurable) + modem DRX histogram + `halide-power top --record 8h` CSV linked. Any gate miss → linked wakelock-sprint issue (ch.11 risk #3 trigger) with owner + date, not a footnote.

## 3. Regression rule

New release vs previous HALIDE (not just stock): >10% regression in any row = automatic P1 + bisect (MANIFEST delta is small — monthly cadence makes bisect cheap; that cheapness is the point of monthly).

## Verification

- [ ] Calibration current (≤6 months); footnotes complete; regression check run.
