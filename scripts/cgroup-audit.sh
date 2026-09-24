#!/bin/bash
# cgroup-audit.sh — per-unit resource limits must be committed (ch.05 §12 binding table).
# Phone-safe: text check on the systemd overlay; live systemctl compare runs on device only.
set -eu
cd "$(dirname "$0")/.."
SVC=debian/overlays/halide-android.service
[ -f "$SVC" ] || { echo "REFUSED: $SVC not found"; exit 2; }

rc=0
for key in MemoryMax MemoryHigh TasksMax CPUWeight; do
  if grep -q "^$key=" "$SVC"; then
    echo "OK: $key set ($(grep "^$key=" "$SVC" | head -n 1))"
  else
    echo "FAIL: $key missing in $SVC (ch.05 §12: drift fails CI; container must not starve host)"
    rc=1
  fi
done
echo "note: live check 'systemctl show -p MemoryMax,TasksMax,CPUWeight halide-android' is device-only"

[ "$rc" -eq 0 ] && echo "CGROUP-AUDIT OK"
exit $rc
