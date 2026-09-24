# RUNBOOK - Sensors (ISensors@2.1-multihal) - ch.04 S21
# Owner: @android-lead - Backup: @platform-lead - Last drill: TODO (fill at
# bring-up; undrilled runbooks expire after 90 days and block the gate).
# Service: android.hardware.sensors@2.1 ISensors, instance multihal, hwbinder.
# Host peer: IIO nodes + AP hub where present; config: sensors_config.json
# (/vendor/etc/sensors_config.json). Inventory: sensors/<sku>/inventory.md
# (vendor string, range, resolution, power draw, on-change vs polling).

## 60-second smoke
lxc-attach -n android -- dumpsys sensorservice | grep -Ei 'handle|name|fifo|wake' | head -20
lxc-attach -n android -- lshal --debug | grep -i -A2 sensors
# Expect: sub-HAL registration + per-sensor enable->read->disable works.

## Failure ladder
1. No events -> IIO node missing?
2. multihal config handle mismatch (sensors_config.json)?
3. SELinux hal_sensors denial in audit.log? (S27 triage)
4. FIFO drops -> watermark IRQ late; shorten batch_timeout with counters.

## Drill (quarterly, backup performs it - S28)
100Hz accel 60s (dropped-batch counter 0) + virtual-sensor unplug/replug.
Wake-vs-non-wake accounting named per handle (unnamed wakes = P1, S32).
