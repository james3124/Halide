#!/usr/bin/env python3
# panic-trend.py — weekly class-count table across logs/*.log (ch.03 §31 closure loop).
# Phone-safe: reads text logs, prints a table; exits 2 with no taxonomy hits at all if none found.
import glob, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    # module file has a dash -> import by path (single source of truth with panic-classify.py)
    import importlib.util
    _spec = importlib.util.spec_from_file_location(
        "panic_classify", os.path.join(os.path.dirname(os.path.abspath(__file__)), "panic-classify.py"))
    _mod = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(_mod)
    TAXONOMY = _mod.TAXONOMY
except Exception:
    TAXONOMY = [
        (r"Unable to handle kernel .* at virtual address", "NULL-DEREF", "driver"),
        (r"Oops: .* \[#\d+\] .* PREEMPT SMP", "OOPS-CONTINUABLE", "pc-owner"),
        (r"Internal error: Oops.*[\s\S]*binder", "BINDER-UAF", "binder IPC"),
        (r"rcu: .*stall detected|rcu_sched detected stalls", "RCU-STALL", "scheduler/power"),
        (r"BUG: workqueue lockup|hung_task: blocked for more than", "HUNG-TASK", "storage/modem"),
        (r"DMAR|arm-smmu .*(Unhandled context|global) fault", "SMMU-FAULT", "IOMMU master"),
        (r"Kernel panic - not syncing: VFS: Unable to mount root fs", "ROOT-MOUNT", "storage/AVB"),
        (r"Kernel panic - not syncing: .*out of memory", "OOM-PANIC", "memory policy"),
        (r"watchdog: BUG: soft lockup", "SOFT-LOCKUP", "CPU-bound driver"),
        (r"stack guard page was hit|Stack overflow", "STACK-OVERFLOW", "deep-call driver"),
    ]


def main(argv):
    logs_dir = "logs"
    if "--logs" in argv:
        logs_dir = argv[argv.index("--logs") + 1]
    files = sorted(glob.glob(os.path.join(logs_dir, "*.log")))
    if not files:
        print("REFUSED: no %s/*.log files yet (weekly standup input per ch.03 §31)" % logs_dir)
        return 2

    counts = {cls: 0 for _, cls, _ in TAXONOMY}
    counts["UNCLASSIFIED"] = 0
    scanned = 0
    for f in files:
        try:
            text = open(f, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        scanned += 1
        for pattern, cls, _ in TAXONOMY:
            counts[cls] += len(re.findall(pattern, text))
    # unclassified = files that matched nothing
    for f in files:
        text = open(f, encoding="utf-8", errors="replace").read()
        if not any(re.search(p, text) for p, _, _ in TAXONOMY):
            counts["UNCLASSIFIED"] += 1

    print("PANIC-TREND over %d log(s):" % scanned)
    print("| class | count |")
    print("|---|---|")
    for cls, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        print("| %s | %d |" % (cls, n))
    print("new class = new taxonomy row MR within 7d, owner at standup (ch.03 §31)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
