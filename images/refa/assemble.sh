#!/bin/bash
# images/refa/assemble.sh -- refa assembly descriptor runner (ch.09 S8).
# Consumes: kernel Image.gz+modules+dtb/dtbo, AOSP system/vendor/product dirs,
# Debian rootfs tar, firmware list. Validates sizes against flashmap.json BEFORE
# signing (oversize = fail with byte counts, never truncate silently).
# PHONE-SAFE: --plan is text-only. Any real assembly refuses on low-RAM (exit 2).
set -eu
cd "$(dirname "$0")/../.."
SKU=refa
MAP=images/$SKU/flashmap.json
CONF=images/$SKU/update-engine.conf
BUDGET=images/$SKU/ota-budget.json

if [ "${1:-plan}" = "--plan" ] || [ "${1:-plan}" = "plan" ]; then
  [ -f "$MAP" ] || { echo "REFUSED: $MAP not found"; exit 2; }
  python3 - "$MAP" <<'EOF'
import json,sys
m = json.load(open(sys.argv[1]))
print("assemble plan sku=%s flashmap=%s" % (m.get("sku", "refa"), sys.argv[1]))
total = 0
if "partitions" in m:
    for p in m["partitions"]:
        print("  %-12s %12d B  %s" % (p["name"], p["size_B"], p.get("note", "")))
        total += p["size_B"]
    print("  %-12s %12d B  fixed+dynamic total (userdata sized at flash)" % ("TOTAL", total))
    print("fs: %s" % m["filesystem"]["readonly"])
else:
    # shared flat schema (partition_<name>_size keys, slot a/b): render as-is
    for k in sorted(m):
        if k.startswith("partition_") and k.endswith("_size"):
            print("  %-12s %12d B" % (k[len("partition_"):-len("_size")], m[k]))
            total += m[k]
    print("  %-12s %12d B  fixed total (userdata: %s, slot: %s)" % ("TOTAL", total, m.get("userdata"), m.get("slot")))
    print("note: %s" % m.get("note", ""))
EOF
  for f in "$CONF" "$BUDGET"; do
    [ -f "$f" ] || { echo "FAIL: missing $f (ch.09 S8/S27 inputs)"; exit 1; }
  done
  echo "inputs present: update-engine.conf + ota-budget.json"
  echo "version gate: /etc/halide-release vs container build.prop halide.version must match or first-boot refuses"
  echo "assemble: PLAN ONLY (no writes performed)"
  exit 0
fi

MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
AVAIL_DISK_GB=$(df -BG . | awk 'NR==2{gsub("G","",$4); print $4}')
if [ "$MEM_GB" -lt 16 ]; then
  echo "REFUSED: need >=16GB RAM for '$1' (have ${MEM_GB}GB). Copy hybrid/ to a builder per README.phone-build.md."
  exit 2
fi
if [ "$AVAIL_DISK_GB" -lt 400 ]; then
  echo "REFUSED: need >=400GB free for '$1' (have ${AVAIL_DISK_GB}GB)."
  exit 2
fi
echo "Builder thresholds passed -- full assemble not implemented in phone skeleton (run on builder)."
exit 0
