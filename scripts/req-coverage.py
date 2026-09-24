#!/usr/bin/env python3
# req-coverage.py — requirements↔tests traceability audit (ch.01 §15: 0 orphans at Phase gates).
# Phone-safe: reads hybrid/reqs/TRACEABILITY.csv, reports orphans; creates nothing. Exit 2 if absent.
import csv, os, sys

CSV_PATH = "reqs/TRACEABILITY.csv"


def main():
    if not os.path.isfile(CSV_PATH):
        print("REFUSED: %s missing — QA owns this file; this script creates nothing (ch.01 §15)" % CSV_PATH)
        return 2

    with open(CSV_PATH, newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))

    expected = {"req_id", "req_text_hash", "design_ref", "test_ids", "gate", "responsible", "status"}
    if rows and not expected.issubset(rows[0].keys()):
        print("FAIL: CSV columns missing; expected to include %s" % sorted(expected))
        return 1

    orphan_reqs = [r["req_id"] for r in rows if not r.get("test_ids", "").strip()]
    orphan_tests = []
    seen_tests = set()
    for r in rows:
        for t in (r.get("test_ids") or "").replace(";", ",").split(","):
            t = t.strip()
            if not t:
                continue
            if t in seen_tests:
                orphan_tests.append(t)  # test row duplicated across reqs without junction marker
            seen_tests.add(t)

    stale = [r["req_id"] for r in rows
             if not r.get("req_text_hash", "").strip() and r.get("status", "") != "DRAFT"]

    print("REQ-COVERAGE: reqs=%d orphan-reqs=%d orphan-tests=%d stale-hash=%d"
          % (len(rows), len(orphan_reqs), len(orphan_tests), len(stale)))
    for i in orphan_reqs:
        print("ORPHAN-REQ: %s (no test_ids — behavior without evidence, ch.01 §15)" % i)
    for t in sorted(set(orphan_tests)):
        print("ORPHAN-TEST: %s (claimed by multiple reqs — fix junction or split row)" % t)
    for s in stale:
        print("STALE: %s (req text changed without hash update)" % s)

    if orphan_reqs or orphan_tests:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
