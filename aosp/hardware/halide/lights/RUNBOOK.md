# RUNBOOK - Lights - ch.04 S21
# Owner: @platform-lead - Backup: @android-lead - Last drill: TODO (fill at
# bring-up; undrilled runbooks expire after 90 days and block the gate).
# Service: android.hardware.light ILights, instance default, transport aidl.
# Host peer: backlight class + leds (single brightness truth in host - slider
# both sides agree; divergence = cache bug, P1). Sheet: lux-curve.csv (S41).

## 60-second smoke
lxc-attach -n android -- dumpsys lights | grep -Ei 'backlight|brightness|led' | head -10
cat /sys/class/backlight/*/brightness; cat /sys/class/backlight/*/max_brightness
# Expect: mirror within 1 step lag (slider sweep host 0->100% + cmd lights
# readback agreement). 5 notification + 5 charging LED patterns by video.

## Failure ladder
1. Slider vs sysfs diverge -> someone cached (single-truth fix, re-run sweep).
2. Buzz/strobe at low nits -> PWM <1000Hz fails (bump PWM or FLICKER-KNOWN).
3. Backlight flaps at threshold -> ALS hysteresis +/-15% missing.

## Drill (quarterly, backup performs it - S28)
Suspend with LED active (no suspend-block from lights service - wakeup audit
S14 catches it) + office-doorway 5-min ALS hysteresis log.
