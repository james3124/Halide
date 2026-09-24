#!/bin/bash
# scripts/ota-build.sh -- OTA payload + delta generation runbook (ch.09 S9/S27).
# Full + incremental (bsdiff/puffdiff + xz envelope, 100M per-file chunk cap),
# wire-byte budgets from images/<sku>/ota-budget.json, metadata.json required
# fields (from/to, size, battery >= 30 pct, changelog URL, deadline, rollback-index).
# PHONE-SAFE: plan/check modes are text-only. Build modes refuse on low-RAM (exit 2).
set -eu
cd "$(dirname "$0")/.."
SKU="${1:-refa}"
MODE="${2:-plan}"
BUDGET=images/$SKU/ota-budget.json
CONF=images/$SKU/update-engine.conf
MAP=images/$SKU/flashmap.json

[ -f "$BUDGET" ] || { echo "REFUSED: $BUDGET not found"; exit 2; }
[ -f "$CONF" ] || { echo "REFUSED: $CONF not found"; exit 2; }

if [ "$MODE" = "plan" ]; then
  python3 - "$BUDGET" <<'EOF'
import json,sys
b = json.load(open(sys.argv[1]))
print("ota plan sku=%s" % b["sku"])
print("  full_cap=%.2fG delta_soft=%.2fG delta_hard=%.2fG fleet_cap=%.2fG" % (
    b["full_cap_B"]/2**30, b["delta_soft_B"]/2**30, b["delta_hard_B"]/2**30, b["fleet_cap_B"]/2**30))
print("  ship incremental only if <= %.0f pct of full AND <= hard cap" % (b["delta_ship_ratio"]*100))
print("  compressor: %s block=%d chunk_cap=%dM" % (b["compressor"], b["block_size"], b["chunk_cap_B"]/2**20))
EOF
  echo "metadata.json required: version-from/to, wire size, battery>=30 + charger-or-override,"
  echo "  changelog URL, deadline, rollback-index (missing field = signing blocked)"
  echo "delta QA matrix: full-path, delta-path, skip-path N-2 full, resume kill at 30/70/95 pct"
  echo "sideload: same payload via ADB with identical verify+health gates"
  exit 0
fi

if [ "$MODE" = "check" ]; then
  META="${3:?usage: ota-build.sh <sku> check <metadata.json>}"
  [ -f "$META" ] || { echo "REFUSED: $META not found"; exit 2; }
  python3 - "$META" "$BUDGET" <<'EOF' || exit 1
import json,sys
m = json.load(open(sys.argv[1])); b = json.load(open(sys.argv[2]))
req = ["version_from","version_to","wire_size_B","battery_min_pct","changelog_url","deadline","rollback_index"]
missing = [k for k in req if k not in m]
if missing:
    print("FAIL: metadata.json missing: %s (signing blocked)" % ",".join(missing)); sys.exit(1)
if m["battery_min_pct"] < 30:
    print("FAIL: battery_min_pct < 30"); sys.exit(1)
if m["wire_size_B"] > b["full_cap_B"]:
    print("FAIL: wire %d B exceeds full cap %d B" % (m["wire_size_B"], b["full_cap_B"])); sys.exit(1)
print("OTA-METADATA OK: %s -> %s wire=%d rollback=%s" % (
    m["version_from"], m["version_to"], m["wire_size_B"], m["rollback_index"]))
EOF
  exit 0
fi

MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
AVAIL_DISK_GB=$(df -BG . | awk 'NR==2{gsub("G","",$4); print $4}')
if [ "$MEM_GB" -lt 16 ]; then
  echo "REFUSED: need >=16GB RAM for '$MODE' (have ${MEM_GB}GB). Copy hybrid/ to a builder per README.phone-build.md."
  exit 2
fi
if [ "$AVAIL_DISK_GB" -lt 400 ]; then
  echo "REFUSED: need >=400GB free for '$MODE' (have ${AVAIL_DISK_GB}GB)."
  exit 2
fi
echo "Builder thresholds passed -- payload/delta generation runs on builder (bsdiff mem cap 512M/worker)."
exit 0
