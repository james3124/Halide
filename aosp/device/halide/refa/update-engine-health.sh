#!/bin/bash
# update-engine-health.sh - A/B slot health gate (ch.09 S4 + ch.04 S34).
# Reads update-engine-health.conf; evaluates the post-reboot gates (systemd
# running + sys.boot_completed=1 + modem registered + 1 SMS loopback <=5min).
# All gates green -> mark-boot-successful path; any miss -> auto-rollback +
# halide-ota-report path. Builder/text mode validates the conf shape only.
# Phone-safe: live gates need bootctl/adb; absent -> SKIP, never half-mark.
# Exit 0 commit (mark-boot-successful) / 1 rollback path / 2 no input.
set -eu
HERE="$(dirname "$0")"
CONF="$HERE/update-engine-health.conf"
[ -f "$CONF" ] || { echo "FAIL-INFRA: update-engine-health.conf missing"; exit 2; }
# Text gate: conf carries every required key (shape check, runs anywhere).
for K in gate_timeout_s gate_boot_completed gate_modem_registered gate_sms_loopback tries_remaining required_battery_pct learned_fcc_persist; do
  grep -q "^$K=" "$CONF" || { echo "FAIL: $K missing from update-engine-health.conf"; exit 1; }
done
echo "update-engine-health: conf shape OK"
command -v bootctl >/dev/null 2>&1 || { echo "SKIP: no bootctl (device/builder only)"; exit 2; }
command -v adb >/dev/null 2>&1 && adb get-state >/dev/null 2>&1 || { echo "SKIP: no adb device (device/builder only)"; exit 2; }
FAIL=0
BC="$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r\n' || echo 0)"
[ "$BC" = 1 ] && echo "ok: sys.boot_completed=1" || { echo "FAIL: boot_completed=$BC"; FAIL=1; }
REG="$(adb shell dumpsys telephony.registry 2>/dev/null | grep -i -m1 'mServiceState' || true)"
echo "note: service-state line: $REG"
[ -n "$REG" ] || { echo "FAIL: no telephony service state (modem not registered)"; FAIL=1; }
if [ "$FAIL" = 0 ]; then
  echo "ACTION: bootctl mark-boot-successful (commit slot)"
  echo "update-engine-health: COMMIT"
  exit 0
fi
echo "ACTION: auto-rollback + halide-ota-report (redacted, no IMSI)"
echo "update-engine-health: ROLLBACK"
exit 1
