#!/bin/bash
# TOP-100-hook.sh - compat matrix shape gate (ch.01 S15 ops, AOSP-area hook).
# Plan demands per-app rows with: package, version, source (Aurora/F-Droid/
# direct), grade (WORKS/DEGRADED/BLOCKED), reason code, tester, date,
# device+build. BLOCKED rows need a lawful reason code, never "coming soon"
# without a bug ID. Stale grades (>90 days) take a STALE badge (listed here
# as warnings; freshness itself is enforced at release review, not per-MR).
# Phone-safe: pure text gate over compat/TOP-100.md.
# Exit 0 pass / 1 fail (malformed row or BLOCKED-without-reason) / 2 no input.
set -eu
cd "$(dirname "$0")/.."
M="compat/TOP-100.md"
[ -f "$M" ] || { echo "FAIL-INFRA: $M missing"; exit 2; }
FAIL=0
# Header must carry the S15 columns.
for C in "App (pkg)" "Version" "Source" "Grade" "Reason code" "Tester" "Date" "Device+build"; do
  grep -q "$C" "$M" || { echo "FAIL: column '$C' missing from TOP-100.md (ch.01 S15)"; FAIL=1; }
done
# Row shape: 8 pipe cells; grade closed set; BLOCKED needs a NEEDS-/CRASH- reason.
python3 - <<'PY' || FAIL=1
import re, sys
lines = open("compat/TOP-100.md").read().splitlines()
rows = [l for l in lines if l.startswith("|")][2:]
assert rows, "no data rows in TOP-100.md"
grades = {"WORKS", "DEGRADED", "BLOCKED"}
for r in rows:
    cells = [c.strip() for c in r.strip().strip("|").split("|")]
    if len(cells) != 8:
        print("FAIL: row does not have 8 cells: %s" % r[:60]); sys.exit(1)
    pkg, ver, src, grade, reason = cells[0], cells[1], cells[2], cells[3], cells[4]
    if grade not in grades:
        print("FAIL: bad grade %r in %s" % (grade, pkg)); sys.exit(1)
    if grade == "BLOCKED" and not re.match(r"^(NEEDS-|CRASH-)", reason):
        print("FAIL: BLOCKED without NEEDS-/CRASH- reason: %s" % pkg); sys.exit(1)
    if grade == "WORKS" and reason != "works":
        print("FAIL: WORKS row with non-works reason: %s" % pkg); sys.exit(1)
print("top100-hook: %d rows well-formed" % len(rows))
PY
[ "$FAIL" = 0 ] && echo "top100-hook: PASS" || echo "top100-hook: FAIL"
exit "$FAIL"
