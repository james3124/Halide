# hardware/halide/OWNERS.md - HAL ownership + bus-factor rule (ch.04 S28).
# Every S3/S21 HAL names owner + backup (also in each RUNBOOK header).
# Backup performs the drill quarterly (log names the performer - owner-only
# drills prove nothing). Owner departure without trained backup triggers the
# 90-day succession window (ch.02 S14 pattern); unnamed-successor HALs demote
# to COMMUNITY-grade with release-note honesty, never silent orphaning.
# Onboarding: run the HAL ladder supervised once, results co-signed.
HAL,owner,backup
audio,@android-lead,@platform-lead
camera,@android-lead,@bsp-lead
sensors,@android-lead,@platform-lead
gnss,@telephony,@platform-lead
ril,@telephony,@platform-lead
power,@android-lead,@platform-lead
health,@platform-lead,@android-lead
usb,@platform-lead,@android-lead
lights,@platform-lead,@android-lead
vibrator,@platform-lead,@android-lead
wifi-vendor,@platform-lead,@telephony
bt-vendor,@platform-lead,@telephony
drm-l3,@android-lead,@security
keymaster-sw,@security,@android-lead
thermal,@platform-lead,@android-lead
composer,@platform-lead,@arch
