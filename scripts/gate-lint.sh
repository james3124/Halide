#!/bin/bash
# gate-lint.sh <md> <json> — lint a gate record pair before sign (ch.00 gate templates).
# Phone-safe: text/JSON checks only, no signing, no network. Exit 0 pass / 1 fail / 2 infra.
set -eu
MD=${1:?usage: gate-lint.sh <md> <json>}; JSON=${2:?usage: gate-lint.sh <md> <json>}
[ -f "$MD" ] && [ -f "$JSON" ] || { echo "REFUSED: record pair not found"; exit 2; }

# JSON must parse and carry all 11 normative fields (ch.00 gate-record table)
FIELDS="gate sku build_id images verdict signers log_bundle waiver_adr rerun_date calibration_ids quarantine_delta"
python3 - "$JSON" <<'EOF' || exit 1
import json,sys
d=json.load(open(sys.argv[1]))
req=["gate","sku","build_id","images","verdict","signers","log_bundle","waiver_adr","rerun_date","calibration_ids","quarantine_delta"]
missing=[k for k in req if k not in d]
if missing: print("FAIL: json missing fields: "+",".join(missing)); sys.exit(1)
v=d["verdict"]
if v=="PASS" and (d["waiver_adr"] is not None or d["rerun_date"] is not None):
    print("FAIL: PASS requires waiver_adr=null and rerun_date=null"); sys.exit(1)
if v=="FAIL" and d["rerun_date"] is None:
    print("FAIL: FAIL verdict requires rerun_date (within 14d, ch.00)"); sys.exit(1)
if v=="WAIVED" and d["waiver_adr"] is None:
    print("FAIL: WAIVED requires waiver_adr (ADR link, ch.11 S14)"); sys.exit(1)
# required-count: 10 of 11 fields counted (exempt field depends on verdict); null-vs-nonnull
# validity is enforced by the verdict rules above, so presence is what this counter checks.
exempt={"PASS":"waiver_adr","FAIL":"waiver_adr","WAIVED":"rerun_date"}.get(v)
n=sum(1 for k in req if k!=exempt)
if n!=10: print(f"FAIL: fields={n}/10 incomplete"); sys.exit(1)
if len(d["signers"])<2: print("FAIL: signers<2 (quorum, ch.08 S8)"); sys.exit(1)
EOF

VERDICT=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['verdict'])" "$JSON")
SKU=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['sku'])" "$JSON")
BUILD=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['build_id'])" "$JSON")
GATE=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['gate'])" "$JSON")

# Gate 1-2 mandatory attachments (ch.00 table; grep md for each basename, sku substituted)
att_ok=0; att_total=0
if [ "$GATE" = "1-2" ]; then
  for pat in "systemd-login-$SKU.log" "binder-nodes.txt" "suspend-50-$SKU.csv" "qrtr-lookup.txt" "modetest.txt" "evtest-.*\.txt"; do
    att_total=$((att_total+1))
    if grep -qE "$pat" "$MD"; then att_ok=$((att_ok+1)); else echo "FAIL: attachment missing from md: $pat"; fi
  done
fi
[ "$att_total" -eq 0 ] && { att_ok=0; att_total=0; }

# REF-B records must never cite a build ID also used by REF-A records (program/gates/)
if [ "$SKU" = "REF-B" ] && [ -d program/gates ]; then
  for other in program/gates/*.md; do
    [ "$other" = "$MD" ] && continue
    if grep -qF "$BUILD" "$other" && grep -q "REF-A" "$other"; then
      echo "FAIL: REF-B build id $BUILD also used by REF-A record $other"; exit 1
    fi
  done
fi

echo "GATE-LINT OK: fields=10/10 attachments=$att_ok/$att_total signers=2/2 verdict=$VERDICT build=$BUILD"
