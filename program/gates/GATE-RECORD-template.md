# Gate record template (ch.00 phase gates; calendar: program/GATE-CALENDAR.md).
# Copy to program/gates/<n>-<date>-<SKU>.md + JSON sidecar of the same name.
# No verbal gates: record + sidecar committed before the sign counts. Failed
# gate = dated root-cause week + re-run scheduled here. REF-B never inherits
# REF-A signers or build IDs.

Gate: TODO (e.g. 2-3 GUI + 1 app)
Date: TODO
SKU: TODO (REF-A / REF-B)
Build-ID: TODO (halide-<YYYYMMDD>-<sha12>, frozen at bake stage 1)
Owner-sign-pair: TODO (area + QA; cross-cutting + Arch)
Evidence-links: TODO (committed artifacts, not chat)
Verdict: TODO (PASS / FAIL)
Root-cause-week (if FAIL): TODO (dates + re-run date)

## JSON sidecar (<same-name>.json)
{"gate": "TODO", "date": "TODO", "sku": "TODO", "build_id": "TODO",
 "verdict": "TODO", "signers": ["TODO"], "evidence": ["TODO"]}
