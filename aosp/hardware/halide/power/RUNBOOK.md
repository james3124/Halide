# RUNBOOK - Power (IPower@5 + hint sessions) - ch.04 S21
# Owner: @android-lead - Backup: @platform-lead - Last drill: TODO (fill at
# bring-up; undrilled runbooks expire after 90 days and block the gate).
# Service: android.hardware.power IPower, instance default, transport hwbinder.
# Host peer: cpufreq/devfreq boosts via /run/halide/power-hint (rate-limited).
# Key props: ro.halide.sku, halide.version guard (S15).
# Values: power-hint-values.conf (never hardcoded in power-hal.cpp).

## 60-second smoke
lxc-attach -n android -- dumpsys power | grep -Ei 'hint|sustain|boost' | head -10
lxc-attach -n android -- cmd power hint INTERACTION 500
journalctl -u halide-power-hint -S -2min | grep -E 'INTERACTION|boost' | tail -5
cpupower frequency-info | grep -Ei 'current|governor' | head -4
# Expect: socket log line + cpufreq boost observed within 200ms.

## Failure ladder
1. No boost -> hint socket perms (/run/halide/power-hint)?
2. Host governor powersave pinned by test rig? Unpin per S25.
3. SELinux denial for power HAL in audit.log? Triage per S27 (48h BUG).
4. Boost storm? Rate-limiter counter in metrics must hold (S11).

## Drill (quarterly, backup performs it - S28)
200 rapid hints (storm test, rate-limiter holds) + 10-min sustained soak
(skin-temp + throttle-trip log, ch.02 S6). Ambient + meter cal ID footnoted
(ch.10 S8 - unfootnoted power numbers rejected).
