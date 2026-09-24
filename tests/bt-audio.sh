#!/bin/bash
# tests/bt-audio.sh — BT contract: host BlueZ owns HCI, bridged HFP, A2DP via PipeWire.
# Phone-safe: text checks; live bluetoothctl tests device-only. Exit 0/1/2.
set -u
cd "$(dirname "$0")/.."
FAIL=0

# 1. BT bridge registered in sockets + unit exists
if grep -q "bt.sock" bridges/SOCKETS.md; then :; else echo "note: bt.sock not yet in SOCKETS.md (add with bridge)"; fi
if [ -f debian/overlays/halide-bt-bridge.service ]; then :; else
  echo "FAIL: bt-bridge unit missing"; FAIL=1
fi

# 2. No raw HCI passthrough to container (ch.07 §12 option A ban)
if [ -f debian/overlays/android.conf.in ] && grep -qi "hci" debian/overlays/android.conf.in; then
  echo "FAIL: HCI device exposed to container (ch.07 §12: host owns HCI)"; FAIL=1
else
  echo "OK: no HCI passthrough in container config"
fi

# 3. Audio path: BT codecs limited to host-decoded set (audio/FORMATS.md: SBC/AAC only v1)
# FORMATS.md lists LDAC/aptX as "OFF" — flag only if that OFF marker disappears.
if grep -qE "LDAC.*OFF|aptX.*OFF" audio/FORMATS.md; then
  echo "OK: BT codec set = SBC/AAC (v1), LDAC/aptX marked OFF"
else
  echo "FAIL: audio/FORMATS.md no longer marks LDAC/aptX OFF (v1 codec posture)"; FAIL=1
fi

# 4. HFP AG on host (route table carries BT-SCO path)
if grep -q "BT-SCO" audio/refa/measurements.md 2>/dev/null; then :; else
  echo "note: BT-SCO route not yet in audio/refa/measurements.md"
fi

# 5. Live checks (device-only)
if command -v bluetoothctl >/dev/null 2>&1 && bluetoothctl show >/dev/null 2>&1; then
  if bluetoothctl show | grep -q "Powered: yes"; then
    echo "live: BT powered"
  else
    echo "live: BT down (ok on bench)"
  fi
else
  echo "SKIP: live bluetoothctl (device/builder only)"
fi

if [ "$FAIL" -eq 0 ]; then echo "bt-audio: PASS"; fi
exit "$FAIL"
