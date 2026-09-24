# Calibration: refa sacrificial + dogfood units (ch.10 S8 power methodology).
# Meters lie by 2-5%: document the lie. Uncalibrated numbers are rejected.
# Dogfood units measured via USB-PD meter + upower/health cross-calibration.
# PSU wiring: battery-lead bypass ONLY on the sacrificial unit with battery
# eliminator (never on dogfood units - fuel-gauge behavior differs).

Unit-sacrificial: TODO-label (battery eliminator, PSU leads)
Unit-dogfood: TODO-label (USB-PD meter)
Meter-model-fw: TODO-measured
Meter-offset-vs-reference: TODO-measured % (cal TODO-date, due TODO-date)
Ambient-window: 23+-2C chamber-log: TODO (csv path)
Cell-band-or-shield-profile: TODO-measured
Brightness: 200 nits (lux-meter serial TODO, panel PWM TODO)
Modem-fw: TODO-measured (SHA in BLOBS)
Wlan-fw: TODO-measured (SHA in BLOBS)
upower-health-cross-check: TODO-measured (offset per unit)
Footnote-set: unit label, firmware SHAs, ambient, brightness nits, run count,
  median-vs-mean choice stated (ch.10 S12 - tables without footnotes fail CI).
