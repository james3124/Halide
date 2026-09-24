#!/usr/bin/env python3
# panic-classify.py — first-pass panic classification (ch.03 §31 taxonomy table is normative).
# Phone-safe: regex over a text log; output JSON feeds the BUG title. Exit 0 classified / 1 unknown.
import json, re, sys

# (regex, class, subsystem) — mirrors kernel/panic-taxonomy.csv rows (ch.03 §31 table)
TAXONOMY = [
    (r"Unable to handle kernel .* at virtual address", "NULL-DEREF", "driver (pc symbol owner)"),
    (r"Oops: .* \[#\d+\] .* PREEMPT SMP", "OOPS-CONTINUABLE", "same as pc-owner"),
    (r"Internal error: Oops.*[\s\S]*binder", "BINDER-UAF", "binder IPC"),
    (r"rcu: .*stall detected|rcu_sched detected stalls", "RCU-STALL", "scheduler/power"),
    (r"BUG: workqueue lockup|hung_task: blocked for more than", "HUNG-TASK", "storage or modem-QMI"),
    (r"DMAR|arm-smmu .*(Unhandled context|global) fault", "SMMU-FAULT", "IOMMU master"),
    (r"Kernel panic - not syncing: VFS: Unable to mount root fs", "ROOT-MOUNT", "storage/AVB/ramdisk"),
    (r"Kernel panic - not syncing: .*out of memory", "OOM-PANIC", "memory policy"),
    (r"watchdog: BUG: soft lockup", "SOFT-LOCKUP", "CPU-bound driver"),
    (r"stack guard page was hit|Stack overflow", "STACK-OVERFLOW", "deep-call driver"),
]


def main(argv):
    if "--input" in argv:
        path = argv[argv.index("--input") + 1]
    elif len(argv) >= 1 and not argv[0].startswith("-"):
        path = argv[0]
    else:
        print("usage: panic-classify.py --input <log> [--out <json>]", file=sys.stderr)
        return 2
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError as e:
        print("REFUSED: cannot read %s (%s)" % (path, e), file=sys.stderr)
        return 2

    for pattern, cls, subsys in TAXONOMY:
        m = re.search(pattern, text)
        if m:
            result = {"class": cls, "subsystem": subsys, "first_log": "dmesg-ramoops",
                      "confidence": "high", "snippet": m.group(0)[:80]}
            out = result
            if "--out" in argv:
                with open(argv[argv.index("--out") + 1], "w") as fh:
                    json.dump(result, fh)
                    fh.write("\n")
            print(json.dumps(out))
            print("next: panic-firstlog.sh --class %s --input %s (ch.03 §31 next-command column)" % (cls, path))
            return 0

    print(json.dumps({"class": "UNCLASSIFIED", "subsystem": "?", "confidence": "none"}))
    print("new panic shape = new taxonomy row MR within 7d (ch.03 §31), not tribal knowledge")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
