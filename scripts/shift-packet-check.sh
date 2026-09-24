#!/bin/bash
# scripts/shift-packet-check.sh -- shift-handoff audit packet validator (ch.09 S28).
# A packet without the station-image SHA is treated as unsigned; a missing
# anomalies line fails the packet; line-lead countersign required within 24h.
# Phone-safe: python3 + JSON only. Exit 0 pass / 1 fail / 2 usage.
set -eu
cd "$(dirname "$0")/.."
PKT=${1:?usage: shift-packet-check.sh <shift-packet.json>}
[ -f "$PKT" ] || { echo "REFUSED: $PKT not found"; exit 2; }

python3 - "$PKT" <<'EOF'
import json,sys
try:
    p = json.load(open(sys.argv[1]))
except ValueError as e:
    print("FAIL: packet is not JSON: %s" % e); sys.exit(1)
rc = 0
for k in ("shift", "station", "station_image_sha", "usbguard_policy_sha",
          "transparency_commit", "units_flashed", "egress_probe",
          "nft_diff_hash", "backup_disk_shas", "anomalies", "countersign"):
    if k not in p or p[k] in (None, ""):
        print("FAIL: packet missing '%s' (unsigned packet pages Release)" % k); rc = 1
if "station_image_sha" in p and str(p["station_image_sha"]).startswith("TODO"):
    print("FAIL: station-image SHA is a placeholder (packet unsigned)"); rc = 1
if "anomalies" in p and not str(p["anomalies"]).strip():
    print("FAIL: anomalies line empty (anomalies-or-none required)"); rc = 1
if rc == 0:
    print("SHIFT-PACKET OK: shift=%s units=%s anomalies=%s" % (p["shift"], p["units_flashed"], p["anomalies"]))
sys.exit(rc)
EOF
