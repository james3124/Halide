#!/bin/bash
# tests/display/backlight-uniformity.sh - 9-zone luminance sampling (ch.10 S23).
# Full-white/gray/black captures via external camera; uniformity delta >15%
# center-to-corner files a P2 display-calibration issue (non-gating unless paired
# with a thermal complaint). Phone-safe: rig + lux meter only. Exit 0/1/2.
# DOD: DoD-jank,DoD-logs
set -eu
cd "$(dirname "$0")/../.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_DISPLAY_RIG:-0}" != "1" ]; then
  echo "SKIP: needs fixed mount jig + lux meter HALIDE_DISPLAY_RIG=1 (ch.10 S23) (device/builder only)"; exit 2
fi
if ! command -v halide-lux-capture >/dev/null 2>&1; then
  echo "SKIP: halide-lux-capture not on runner (device/builder only)"; exit 2
fi
mkdir -p logs
OUT=logs/backlight-$(date +%Y%m%d-%H%M%S).csv
echo "pattern,zone,lux" > "$OUT"
for P in white gray black; do
  adb shell halide-display-drive --pattern "$P" --nits 200 >/dev/null 2>&1 \
    || { echo "SKIP: halide-display-drive not on unit (device/builder only)"; exit 2; }
  halide-lux-capture --zones 9 --pattern "$P" >> "$OUT" 2>/dev/null \
    || { echo "FAIL-INFRA: lux capture failed on $P (runner/lab issue)"; exit 2; }
done
DELTA=$(python3 - "$OUT" <<'PY' || echo "?"
import csv, sys
rows = [r for r in csv.DictReader(open(sys.argv[1])) if r["pattern"] == "white"]
vs = [float(r["lux"]) for r in rows if r["lux"].replace(".", "", 1).isdigit()]
if not vs:
    print("?"); sys.exit(0)
mx, mn = max(vs), min(vs)
print("%.1f" % (100.0 * (mx - mn) / mx if mx else 0.0))
PY
)
echo "backlight-uniformity: center-corner delta ${DELTA}% (gate: file P2 if >15%, display-calibration-procedure)" | emit
python3 -c "d='$DELTA'; import sys; sys.exit(0 if d.replace('.','',1).isdigit() and float(d) <= 15.0 else 1)" \
  && { echo "backlight-uniformity: PASS"; exit 0; }
echo "backlight-uniformity: FAIL (uniformity delta ${DELTA}% > 15% - file P2, CSV: $OUT)" | emit; exit 1
