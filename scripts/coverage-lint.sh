#!/bin/bash
# coverage-lint.sh — DoD→suite coverage map checks (ch.10 §9: prose claims don't count).
# Phone-safe: CSV + file existence only. Exit 0 clean / 1 violation / 2 infra.
set -eu
cd "$(dirname "$0")/.."
CSV=qa/coverage-map.csv
[ -f "$CSV" ] || { echo "REFUSED: $CSV not found (QA creates it; this script creates nothing)"; exit 2; }

want="dod_id,area,gate,suite,script,gating(Y/N),evidence_path,owner"
header=$(head -n 1 "$CSV")
if [ "$header" != "$want" ]; then
  echo "FAIL: header is '$header', want '$want'"; exit 1
fi

rc=0; rows=0; gating=0
# Quoted-CSV parsing needs a real parser (gate descriptions contain commas), so the
# row checks run in python3 (already a hard repo dependency); bash keeps the exit contract.
python3 - "$CSV" <<'EOF'
import csv, os, re, sys
fails = 0; rows = 0; gating = 0
with open(sys.argv[1], newline='', encoding='utf-8') as fh:
    for row in csv.DictReader(fh):
        if not (row.get('dod_id') or '').strip():
            continue
        rows += 1
        if (row.get('gating(Y/N)') or '').strip() != 'Y':
            continue
        gating += 1
        for raw in (row.get('script') or '').split('+'):
            part = re.sub(r'\s*\(.*\)', '', raw).strip().split(' ')[0]
            if not part or part.startswith('--'):
                continue
            p = part[len('hybrid/'):] if part.startswith('hybrid/') else part
            if not os.path.isfile(p):
                print(f"FAIL: {row.get('dod_id')} gating=Y script not found: {p}")
                fails += 1
print(f"COVERAGE-ROWS rows={rows} gating={gating}")
sys.exit(1 if fails else 0)
EOF
rc=$?
rows=$(python3 -c "import csv;print(sum(1 for r in csv.DictReader(open('$CSV',encoding='utf-8')) if (r.get('dod_id') or '').strip()))")
gating=$(python3 -c "import csv;print(sum(1 for r in csv.DictReader(open('$CSV',encoding='utf-8')) if (r.get('gating(Y/N)') or '').strip()=='Y'))")
if [ "$rc" -ne 0 ]; then
  echo "COVERAGE-LINT FAIL"; exit 1
fi
echo "COVERAGE-LINT OK: rows=$rows gating=$gating (quarantine cap-5 rule per ch.10 §11)"
