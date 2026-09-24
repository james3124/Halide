# RUNBOOK - Vibrator (IVibrator AIDL) - ch.04 S21
# Owner: @platform-lead - Backup: @android-lead - Last drill: TODO (fill at
# bring-up; undrilled runbooks expire after 90 days and block the gate).
# Service: android.hardware.vibrator IVibrator, instance default, aidl.
# Host peer: leds/vibrator or input-ff. Sheet: waveforms.csv (S41) with
# current-draw note per pattern (haptics is a power line item).

## 60-second smoke
lxc-attach -n android -- dumpsys vibrator | grep -Ei 'amplitude|effect|duration' | head -10
for a in 26 128 255; do lxc-attach -n android -- cmd vibrator vibrate 100 $a; sleep 1; done
# Expect: 10/50/100% sweep + click/tick/call-pattern catalog; duration +/-10ms
# on 100ms pulse; click audible <40dBA@10cm (buzz = resonance miss, re-tune).

## Failure ladder
1. No vibe -> leds/vibrator node present? input-ff claim conflict?
2. SELinux denial in audit.log? (S27 triage)
3. Worn-motor amplitude drop >20% -> MOTOR-WORN RMA track (ch.02 S18).

## Drill (quarterly, backup performs it - S28)
5-min call-pattern loop (thermal + driver stability; ambient + meter cal ID
footnoted, ch.10 S8).
