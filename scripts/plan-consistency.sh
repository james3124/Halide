#!/bin/bash
# plan-consistency.sh — cross-chapter identifier registry drift check (ch.00 registry).
# --strict also fails on alias spellings (e.g. halide_android.service). Phone-safe: grep only.
set -eu
STRICT=0
[ "${1:-}" = "--strict" ] && STRICT=1

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PLAN_DIR=""
if [ -d "$ROOT/hybrid-os-plan" ]; then PLAN_DIR="$ROOT/hybrid-os-plan";
elif [ -d "$ROOT/../hybrid-os-plan" ]; then PLAN_DIR="$ROOT/../hybrid-os-plan";
else echo "REFUSED: hybrid-os-plan not found"; exit 2; fi
cd "$(dirname "$PLAN_DIR")"

fail() { echo "CONSISTENCY FAIL: $1"; exit 1; }

props=(sys.boot_completed sys.halide.bridge ro.halide.slot persist.halide.apn_override sys.halide.crash_banner ro.build.halide)
sockets=(/run/halide/prop.sock /run/halide/ril.sock /run/halide/display-0 /dev/binder org.halide.Modem /mnt/android/system)
units=(halide-android.service halide-prop-bridge.service halide-ril-bridge.service halide-composer.service halide-bootstage.service halide-ota-finalize.service)
metrics=(dogfood_p0_per_1k_days nightly_boot_rate mr_merge_latency_p50_h out_of_tree_lines panel.json power-sheet)
gates=("Gate 0→1" "Gate 1→2" "Gate 2→3" "Gate 3→release")

check() { # name array
  local name=$1; shift; local ok=0 total=0
  for id in "$@"; do total=$((total+1))
    if grep -rqlF "$id" hybrid-os-plan/*.md; then ok=$((ok+1));
    else echo "MISSING: $id"; fi
  done
  echo "$name=$ok/$total"
  [ "$ok" -eq "$total" ] || exit 1
}

fp=$(check props "${props[@]}")
fs=$(check sockets "${sockets[@]}")
fu=$(check units "${units[@]}")
fm=$(check metrics "${metrics[@]}")
fg=$(check gates "${gates[@]}")

# 12 core chapter files must exist
files_ok=0
for n in 00 01 02 03 04 05 06 07 08 09 10 11; do
  ls hybrid-os-plan/$n-*.md >/dev/null 2>&1 && files_ok=$((files_ok+1)) || echo "MISSING: chapter $n"
done
ff="files=$files_ok/12"
[ "$files_ok" -eq 12 ] || exit 1

if [ "$STRICT" -eq 1 ]; then
  # aliases: underscore variants of unit spellings must not appear in plan prose
  if grep -rnq "halide_android\.service" hybrid-os-plan/*.md; then fail "alias spelling halide_android.service"; fi
  if grep -rnq "halide_prop_bridge\.service" hybrid-os-plan/*.md; then fail "alias spelling halide_prop_bridge.service"; fi
  if grep -rnq "halide_ril_bridge\.service" hybrid-os-plan/*.md; then fail "alias spelling halide_ril_bridge.service"; fi
  if grep -rnq "halide_composer_service" hybrid-os-plan/*.md; then fail "alias spelling halide_composer_service"; fi
fi

echo "CONSISTENCY OK: $fp $fs $fu $fm $fg $ff"
