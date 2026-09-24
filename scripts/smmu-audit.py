#!/usr/bin/env python3
# smmu-audit.py — count SMMU context/global faults by stream ID from a dmesg (ch.03 §39).
# Phone-safe: regex over a text file; 0 faults = AUDIT PASS. Exit 0 clean / 1 faults / 2 infra.
import re, sys


def main(argv):
    if not argv:
        print("usage: smmu-audit.py <dmesg-or-pstore-log>", file=sys.stderr)
        return 2
    try:
        text = open(argv[0], encoding="utf-8", errors="replace").read()
    except OSError as e:
        print("REFUSED: cannot read %s (%s)" % (argv[0], e), file=sys.stderr)
        return 2

    # arm-smmu fault lines: "arm-smmu <addr>: Unhandled context fault: fsr=... stream <id>" variants
    fault_lines = [l for l in text.splitlines()
                   if re.search(r"(?:arm-smmu|DMAR)", l, re.I)
                   and re.search(r"(?:context fault|global fault)", l, re.I)]

    if not fault_lines:
        print("AUDIT PASS: 0 SMMU faults (0 context, 0 global)")
        return 0

    by_stream = {}
    sid_re = re.compile(r"(?:stream[- ]?id|sid|stream)\s*[:= ]\s*([0-9a-fA-Fx]+)", re.I)
    for line in fault_lines:
        m = sid_re.search(line)
        sid = m.group(1) if m else "unknown"
        by_stream[sid] = by_stream.get(sid, 0) + 1
    print("SMMU-FAULTS: %d total" % len(fault_lines))
    print("| stream id | count |")
    print("|---|---|")
    for sid, n in sorted(by_stream.items(), key=lambda kv: -kv[1]):
        print("| %s | %d |" % (sid, n))
    print("triage per ch.03 §39: FAR/FSR/CB parse — do NOT binder-triage an IOMMU fault")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
