# Power results TEMPLATE - REF-A - <ver> (ch.10 S8, ch.02 S6).
# Copy to power/REF-A/results-<ver>.md per release and fill with medians of 3 runs
# under identical conditions vs the stock oracle. NEVER invent numbers:
# unmeasured cells stay TODO-measured. Gate miss = linked wakelock-sprint issue
# with owner + date (ch.11 risk-3 trigger), not a footnote.
# Calibration header: power/REF-A/calibration.md (must be current, <=6 months).

| Scenario | HALIDE med | Stock med | Delta | Gate | Verdict |
|---|---|---|---|---|---|
| Overnight 8h suspend (mA mean) | TODO-measured | TODO-measured | TODO-measured % | <=2x stock | TODO |
| Browsing 1h SOT (mA) | TODO-measured | TODO-measured | TODO-measured % | report | TODO |
| Voice 30min (mA) | TODO-measured | TODO-measured | TODO-measured % | report | TODO |
| Hotspot 30min (MB/mA) | TODO-measured | TODO-measured | TODO-measured % | report | TODO |
| Video 720p 30min (mA) | TODO-measured | TODO-measured | TODO-measured % | report | TODO |
| Camera burst 10min (peak skin C) | TODO-measured | TODO-measured | - | <=45C | TODO |
| Suspend residency % (rpm_stats) | TODO-measured | TODO-measured | - | >90% overnight | TODO |

Attachments: top-10 wakeup_sources diff (halide vs stock-approximate) + modem DRX
histogram + halide-power top --record 8h CSV link: TODO-measured.
Flash-wear footer: WA factor TODO-measured (sectors-written over soak /
user-data delta) vs UFS TBW rating: TODO-measured (ch.10 S15 estimate, honest).
Regression rule: >10% vs previous HALIDE in any row = automatic P1 + bisect.
Soak-thermal rows (ch.10 S28): skin TODO-measured C, clocks TODO-measured %,
cooldown <35C by min 10: TODO-measured.
Footnotes (ch.10 S12): unit TODO, firmware SHAs TODO, ambient TODO, nits TODO,
runs TODO, median-vs-mean choice TODO.
