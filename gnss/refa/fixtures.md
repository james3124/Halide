# GNSS fixtures (text-only)
- Fixture: open-sky point lat/lon recorded per lab site log.
- Cold start gate: TTFF <= 60 s, 3/3 runs.
- Warm start gate: TTFF <= 20 s stub, refine after field data.
- Tool: mmcli/gpsNMEA log only; no SUPL secrets here.
- Fail action: re-seat antenna, re-run, attach NMEA.
- Ref ch. GNSS; antenna cable loss see rf/cable-loss.csv.
- No binaries; almanac outside repo. Owner: GNSS bring-up; date each run.
