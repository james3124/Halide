#!/bin/bash
# emergency-label-lint.sh — emergency-matrix must exist and cover every emergency number
# (telephony/emergency-matrix.csv normative, emergency-call-certification.md §2/§5).
# Phone-safe: CSV text check. Exit 0 covered / 1 gap / 2 infra.
set -eu
cd "$(dirname "$0")/.."
CSV=telephony/emergency-matrix.csv
[ -f "$CSV" ] || { echo "REFUSED: $CSV not found"; exit 2; }

header=$(head -n 1 "$CSV")
case "$header" in
  region,*number*|*,number*) : ;;
  *) echo "FAIL: header '$header' lacks region/number columns"; exit 1 ;;
esac

# required numbers (emergency-call-certification.md §2): US 911, EU 112, UK 999+112,
# JP 110/118/119, AU 000+112 — every shipped label needs a row per number
rc=0
for num in 911 112 999 000 110 118 119; do
  if tail -n +2 "$CSV" | awk -F, -v n="$num" '$2==n {found=1} END{exit !found}'; then
    echo "OK: $num covered"
  else
    echo "FAIL: no row for emergency number $num (label would claim coverage without a test row)"
    rc=1
  fi
done

rows=$(tail -n +2 "$CSV" | grep -cvE '^\s*$' || true)
[ "$rc" -eq 0 ] && echo "EMERGENCY-LABEL-LINT OK: $rows row(s) cover all 7 required numbers"
exit $rc
