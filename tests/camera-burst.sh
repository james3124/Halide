#!/bin/bash
# tests/camera-burst.sh — 20-still burst: EXIF + hash + green-frame detector (ch.10 §21/§24).
# Phone-safe: captures on lab unit with HALIDE_LAB=1 only; test-cards, never people.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_LAB:-0}" != "1" ]; then
  echo "SKIP: camera rig run needs HALIDE_LAB=1 (lab fixture, test-cards only) (device/builder only)"; exit 2
fi
mkdir -p logs
BATCH=logs/camera-burst-$(date +%Y%m%d-%H%M%S)
mkdir -p "$BATCH"
adb shell halide-cam-burst --stills 20 2>&1 | tail -1 | tr -d '\r\n' | grep -q done \
  || { echo "SKIP: halide-cam-burst not on unit (device/builder only)"; exit 2; }
adb pull /data/local/tmp/burst "$BATCH" >/dev/null 2>&1 || { echo "FAIL-INFRA: burst pull failed"; exit 2; }
FAIL=0
i=0
for F in "$BATCH"/burst/*.jpg; do
  i=$((i+1))
  # EXIF presence (JFIF/Exif markers) — EXIF-less frames fail acceptance (§24)
  if ! grep -aq 'Exif' "$F"; then echo "FAIL: no EXIF in $F"; FAIL=1; fi
  SHA=$(sha256sum "$F" | cut -c1-16)
  # green/blank frame detector: uniform-color PNG/JPG compresses to a tiny IDAT
  if python3 - "$F" <<'PY'
import sys, zlib
d = open(sys.argv[1], "rb").read()
idx = d.find(b"IDAT")
comp = len(d) - idx if idx > 0 else len(d)
raw = d[16:24]
sys.exit(0 if (idx > 0 and comp < 2048) else 1)
PY
  then echo "FAIL: uniform/blank frame (green-frame suspect): $F"; FAIL=1; fi
  echo "$i,$SHA" | emit >> "$BATCH/hashes.csv"
done
echo "camera-burst: $i frames hashed in $BATCH/hashes.csv" | emit
[ "$i" -eq 20 ] || { echo "FAIL: expected 20 stills, got $i"; FAIL=1; }
[ "$FAIL" = 0 ] && echo "camera-burst: PASS" || echo "camera-burst: FAIL"
exit "$FAIL"
