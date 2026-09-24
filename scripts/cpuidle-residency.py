#!/usr/bin/env python3
# cpuidle-residency.py — read cpuidle residency sysfs into an md table (ch.03 §22 power ladder).
# Phone-safe: read-only sysfs or text diff of before/after snapshots; exit 2 when data absent.
import argparse, glob, os, re, sys


def read_live():
    states = []
    for d in sorted(glob.glob("/sys/devices/system/cpu/cpu0/cpuidle/state*")):
        def rd(name):
            p = os.path.join(d, name)
            return open(p).read().strip() if os.path.isfile(p) else "?"
        states.append({"name": rd("name"), "residency": rd("residency"),
                       "latency": rd("latency"), "usage": rd("usage"), "time": rd("time")})
    return states


def read_snap(p):
    try:
        lines = open(p, encoding="utf-8", errors="replace").readlines()
    except OSError:
        print("REFUSED: cannot read snapshot %s (capture on device per ch.03 §22)" % p)
        sys.exit(2)
    rows = []
    for line in open(p, encoding="utf-8", errors="replace"):
        m = re.match(r"(\S+)\s+residency=(\S+)\s+usage=(\S+)\s+time=(\S+)", line)
        if m:
            rows.append(dict(name=m.group(1), usage=int(m.group(3)), time=int(m.group(4))))
    return rows


def main():
    ap = argparse.ArgumentParser(description="cpuidle residency table (md)")
    ap.add_argument("--before"); ap.add_argument("--after"); ap.add_argument("--format", default="md")
    a = ap.parse_args()

    if a.before and a.after:
        b, c = read_snap(a.before), read_snap(a.after)
        if not b or not c:
            print("REFUSED: snapshot files lack 'name residency= usage= time=' rows (capture on device)")
            return 2
        print("| state | time before | time after | delta |")
        print("|---|---|---|---|")
        after = {r["name"]: r for r in c}
        for r in b:
            o = after.get(r["name"], {"time": 0})
            print("| %s | %d | %d | %+d |" % (r["name"], r["time"], o["time"], o["time"] - r["time"]))
        return 0

    states = read_live()
    if not states:
        print("REFUSED: no /sys/devices/system/cpu/cpu0/cpuidle/state* on this host (device only)")
        return 2
    print("| state | residency(us) | latency(us) | usage | time(us) |")
    print("|---|---|---|---|---|")
    for s in states:
        print("| %s | %s | %s | %s | %s |" % (s["name"], s["residency"], s["latency"], s["usage"], s["time"]))
    print("target: deep-sleep residency >90% overnight on 4GB tier (ch.03 §22 / low-spec §2)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
