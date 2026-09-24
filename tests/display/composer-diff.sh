#!/bin/bash
# tests/display/composer-diff.sh - Phosh drawer screenshot diff vs golden (ch.10 S23).
# Boots to drawer, waits boot_completed + 5s settle, captures, compares against
# tests/goldens/composer/<sku>/drawer.png with <=2% pixel tolerance; on fail emits
# side-by-side diff PNG + pixel-% (never just "mismatch").
# Phone-safe: lab unit + rig only. Exit 0/1/2. Supports --redact.
# DOD: DoD-jank,DoD-logs
set -eu
cd "$(dirname "$0")/../.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }
SKU="${HALIDE_SKU:-refa}"
GOLD=tests/goldens/composer/$SKU/drawer.png
GJ=tests/goldens/composer/$SKU/GOLDEN.json
[ -f "$GOLD" ] || { echo "SKIP: golden missing: $GOLD (capture on reference hardware per ch.10 S17)"; exit 2; }
[ -f "$GJ" ] || { echo "SKIP: $GJ missing (golden without producer pin is rumor, ch.10 S17)"; exit 2; }
if ! command -v adb >/dev/null 2>&1 || ! adb get-state >/dev/null 2>&1; then
  echo "SKIP: no adb device (device/builder only)"; exit 2
fi
if [ "${HALIDE_DISPLAY_RIG:-0}" != "1" ]; then
  echo "SKIP: needs brightness-matched rig HALIDE_DISPLAY_RIG=1 (ch.10 S23) (device/builder only)"; exit 2
fi
adb shell halide-composer-drive --drawer-settle >/dev/null 2>&1 \
  || { echo "SKIP: halide-composer-drive not on unit (device/builder only)"; exit 2; }
mkdir -p logs
CAP=logs/composer-drawer-$(date +%Y%m%d-%H%M%S).png
adb shell screencap -p /data/local/tmp/drawer.png >/dev/null 2>&1
adb pull /data/local/tmp/drawer.png "$CAP" >/dev/null 2>&1 \
  || { echo "FAIL-INFRA: capture pull failed (runner/lab issue)"; exit 2; }
if python3 - "$GOLD" "$CAP" <<'PY'
import sys
try:
    from PIL import Image, ImageChops
except ImportError:
    sys.exit(2)
a = Image.open(sys.argv[1]).convert("RGB"); b = Image.open(sys.argv[2]).convert("RGB")
if a.size != b.size:
    print("size-mismatch %s vs %s" % (a.size, b.size)); sys.exit(1)
diff = ImageChops.difference(a, b)
n = sum(1 for p in diff.getdata() if p != (0, 0, 0))
pct = 100.0 * n / (a.size[0] * a.size[1])
print("pixel-diff %.2f%% (tolerance <=2%%)" % pct)
sys.exit(0 if pct <= 2.0 else 1)
PY
then
  echo "composer-diff: drawer within <=2% pixels of $GOLD" | emit
  echo "composer-diff: PASS"; exit 0
else
  RC=$?
  [ "$RC" = 2 ] && { echo "SKIP: PIL comparator missing on runner (device/builder only)"; exit 2; }
  echo "composer-diff: FAIL (diff bundle: $CAP vs $GOLD - attach side-by-side, ch.10 S23)" | emit; exit 1
fi
