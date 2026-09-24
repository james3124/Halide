# RUNBOOK - USB (IUsb AIDL) - ch.04 S21
# Owner: @platform-lead - Backup: @android-lead - Last drill: TODO (fill at
# bring-up; undrilled runbooks expire after 90 days and block the gate).
# Service: android.hardware.usb IUsb, instance default, transport aidl.
# Host peer: configfs gadget + halide-usb daemon (host owns role-switch S11).
# Key props: ro.halide.sku. Matrix: gadget-matrix.csv (9 states).

## 60-second smoke
lxc-attach -n android -- dumpsys usb | grep -Ei 'accessory|function|state' | head -10
ls /sys/class/udc/ # UDC bound?
journalctl -u halide-usb -S -5min | grep -Ei 'compose|bind|WEDGE' | tail -5
# Expect: lsusb on attached PC + dumpsys usb accessory state agree.

## Failure ladder
1. Gadget missing -> configfs mounted? UDC bound? halide-usb daemon state?
2. Mirror lag >3s -> bridge, not UDC (lag histogram archived).
3. Wedge (bind-absent >5s) -> watchdog rebinds previous-known-good + metric.

## Drill (quarterly, backup performs it - S28)
20 rapid function switches (wedge-counter 0, VID/PID stable, mirror agrees
within 3s each) + role-switch both orientations (C-to-C + C-to-A).
