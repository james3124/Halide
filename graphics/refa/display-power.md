# display power per SKU (ch06 s17) - TEMPLATE, no measured watts yet
# Meter calibration ID (ch10 s8): TODO-measured (unfootnoted watts rejected)
# Panel backlight curve (nits->mA, 5+ pts, from panel.json curve):
#   TODO-measured: table level,nits,mA (lux meter + current meter, same run)
# DSI link (video vs cmd idle deltas, where supported):
#   TODO-measured: mA delta or NOT-SUPPORTED
# GPU (Freedreno/Turnip active vs static PSR):
#   TODO-measured: 30-min static current with/without PSR; PSR kept iff win >=5mA
# Composer present cost (per-present CPU us from frame-join import/commit cols):
#   TODO-measured: us/present; wakeups line item in halide-power top budget
# Backlight floor: TODO-measured: max(legibility nits 3-reviewer, PWM flicker-free floor)
# Suspend path: panel-off -> onPause <=500ms (trace markers DISPLAY_OFF/ONPAUSE_SENT)
# AOD: off v1. TODO-measured: AOD static mA vs full-suspend mA delta on sacrificial.
# Status: UNMEASURED - sacrificial run pending. Do not publish watts from this file.
