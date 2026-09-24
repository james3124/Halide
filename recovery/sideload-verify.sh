#!/bin/sh
# recovery/sideload-verify.sh - sideload verify-then-write gate (runbook-recovery S2).
# Phone-safe STUB: states the gate order, refuses to flash from here.
# Gate: key + rollback-index + size-vs-flashmap verify BEFORE writing; bad payload
# aborts pre-write; operator progress per partition (%, not spinner).
set -eu
echo "sideload-verify plan (text only):"
echo "1. verify payload: key + rollback-index + size vs flashmap"
echo "2. abort BEFORE writing on verify fail (verify-then-write, never reverse)"
echo "3. write inactive slot, mark staged, reboot, health gate (systemd + boot_completed + MM <=5min)"
echo "4. commit or auto-rollback + halide-ota-report"
echo "refusing to execute on phone: destructive + needs builder/fastboot" >&2
exit 2
