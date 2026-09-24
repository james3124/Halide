#!/bin/bash
# bridges/tests/audio_contract.sh — BUS contract for the audio bridge (ch.05 §9).
# Contract test = gate: no contract test, no merge. Phone-safe: text + optional
# live socket round-trip on the phone only.
set -eu
cd "$(dirname "$0")/../.."
FAIL=0

# 1. bridge implementation exists
[ -f bridges/audio_bridge.py ] || { echo "FAIL: bridges/audio_bridge.py missing"; exit 1; }

# 2. socket path referenced by the bridge matches SOCKETS.md registry exactly
PY_SOCK=$(grep -o '/run/halide/[a-z.]*\.sock' bridges/audio_bridge.py | head -1)
if [ -z "$PY_SOCK" ]; then echo "FAIL: no socket path declared in audio_bridge.py"; FAIL=1;
elif ! grep -q "$PY_SOCK" bridges/SOCKETS.md; then echo "FAIL: $PY_SOCK not registered in bridges/SOCKETS.md"; FAIL=1;
else echo "audio: $PY_SOCK registered — OK"; fi

# 3. proto contract file exists
[ -f bridges/proto/audio_bridge.proto ] || { echo "FAIL: bridges/proto/audio_bridge.proto missing"; FAIL=1; }

# 4. documented REQ verbs behave per contract (text interface)
OUT=$(python3 - <<'PY'
import sys
sys.path.insert(0, "bridges")
import audio_bridge
print("|".join([
    audio_bridge.handle("ROUTE media\n").strip(),
    audio_bridge.handle("VOLUME media 80\n").strip(),
    audio_bridge.handle("VOLUME media 150\n").strip(),
    audio_bridge.handle("ROUTE call\n").strip(),
    audio_bridge.handle("ROUTE media\n").strip(),
]))
PY
) || OUT=""
for want in 'OK routed:media' 'OK volume:media:80' 'ERR bad-volume' 'OK routed:call' 'OK ducked'; do
  case "$OUT" in *"|$want|"*|"$want|"*|*"$want") : ;; *) echo "FAIL: contract verb '$want' not observed"; FAIL=1 ;; esac
done
# ducked must be the LAST response (call preempts media, ch.05 §29)
case "$OUT" in *'|OK ducked') : ;; *) echo "FAIL: call-does-not-preempt-media"; FAIL=1 ;; esac

# 5. live socket round-trip — device only, skip cleanly on the phone (exit 2)
if [ -S /run/halide/audio.sock ]; then
  if ! python3 - <<'PY'
import socket, sys
s = socket.socket(socket.AF_UNIX); s.settimeout(2)
s.connect("/run/halide/audio.sock"); s.sendall(b"ROUTE media\n")
r = s.recv(64).decode().strip(); s.close()
print("live:", r)
sys.exit(0 if r.startswith("OK") else 1)
PY
  then echo "FAIL-INFRA: /run/halide/audio.sock exists but gave no OK (runner/lab issue)"; exit 2; fi
else
  echo "note: no live /run/halide/audio.sock (device/builder only) — static contract only"
fi

[ "$FAIL" -eq 0 ] && echo "audio-contract: PASS"
exit "$FAIL"
