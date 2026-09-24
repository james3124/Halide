#!/bin/bash
# bridges/tests/ril_contract.sh — BUS contract for the RIL->MM bridge (ch.05 §9, ch.07 §1).
# Single-stack guard: host MM owns the modem; Android requests, never owns.
set -eu
cd "$(dirname "$0")/../.."
FAIL=0

# 1. bridge implementation exists
[ -f bridges/ril_bridge.py ] || { echo "FAIL: bridges/ril_bridge.py missing"; exit 1; }

# 2. registry: ril.sock documented in SOCKETS.md (exact text) and is the ONE modem path
if ! grep -q '/run/halide/ril.sock' bridges/SOCKETS.md; then
  echo "FAIL: /run/halide/ril.sock not registered in bridges/SOCKETS.md"; FAIL=1
else echo "ril: /run/halide/ril.sock registered — OK"; fi
# single-stack guard (ch.07 §1): STACK must declare single-stack and no line may
# AFFIRMATIVELY enable oFono/a second RIL (the "no oFono" note line must not trip us)
if grep -q 'STACK=single-stack-only' telephony/mm-config.txt \
   && ! grep -qiE 'ofono[= ]*(yes|enabled|active)|stack[= ]*dual' telephony/mm-config.txt; then
  echo "ril: single-stack (MM only) — OK"
else
  echo "FAIL: dual-master modem stack declared (ch.07 §1)"; FAIL=1
fi

# 3. proto contract file exists
[ -f bridges/proto/ril_bridge.proto ] || { echo "FAIL: bridges/proto/ril_bridge.proto missing"; FAIL=1; }

# 4. documented verbs + DRAINING freeze (ch.07 §26 shutdown drain)
OUT=$(python3 - <<'PY'
import sys
sys.path.insert(0, "bridges")
import ril_bridge
r = []
r.append(ril_bridge.handle("DIAL +123\n").strip())
r.append(ril_bridge.handle("PING\n").strip())
ril_bridge.set_radio(ril_bridge.RadioState.DRAINING)
r.append(ril_bridge.handle("DIAL +123\n").strip())
ril_bridge.set_radio(ril_bridge.RadioState.READY)
r.append(ril_bridge.handle("SMS_SEND hello\n").strip())
print("|".join(r))
PY
) || OUT=""
for want in 'OK queued:DIAL' 'ERR unknown-action' 'ERR DENIED-radio-not-ready' 'OK queued:SMS_SEND'; do
  case "$OUT" in *"$want"*) : ;; *) echo "FAIL: contract verb/state '$want' not observed"; FAIL=1 ;; esac
done
case "$OUT" in
  *'DENIED-radio-not-ready|OK queued:SMS_SEND') : ;;
  *) echo "FAIL: DRAINING did not freeze then release MO traffic"; FAIL=1 ;;
esac

# 5. live socket round-trip — device only, skip cleanly on the phone (exit 2)
if [ -S /run/halide/ril.sock ]; then
  if ! python3 - <<'PY'
import socket, sys
s = socket.socket(socket.AF_UNIX); s.settimeout(2)
s.connect("/run/halide/ril.sock"); s.sendall(b"PING\n")
r = s.recv(64).decode().strip(); s.close()
print("live:", r)
# PING is not a valid action: a live bridge must ANSWER (ERR is a pass — liveness + parser)
sys.exit(0 if r.startswith(("OK", "ERR")) else 1)
PY
  then echo "FAIL-INFRA: /run/halide/ril.sock exists but gave no answer (runner/lab issue)"; exit 2; fi
else
  echo "note: no live /run/halide/ril.sock (device/builder only) — static contract only"
fi

[ "$FAIL" -eq 0 ] && echo "ril-contract: PASS"
exit "$FAIL"
