#!/usr/bin/env python3
# initcall-rank.py — rank initcall durations from an initcall_debug dmesg (ch.03 boot-triage §14).
# Phone-safe: regex over a text file; triage order = slowest initcall first, argue from ranking.
import re, sys

LINE = re.compile(r"initcall\s+(\S+?)(?:\+0x[0-9a-fx]+)?\s+returned\s+(\d+)\s+after\s+(\d+)\s+usecs")


def main(argv):
    path = argv[0] if argv else "-"
    try:
        text = open(path, encoding="utf-8", errors="replace").read() if path != "-" else sys.stdin.read()
    except OSError as e:
        print("REFUSED: cannot read %s (%s)" % (path, e), file=sys.stderr)
        return 2

    rows = [(fn, int(us)) for fn, _, us in LINE.findall(text)]
    if not rows:
        print("FAIL: no 'initcall <fn> returned 0 after <us>' lines (boot with initcall_debug on eng)")
        return 1
    rows.sort(key=lambda r: -r[1])

    print("| rank | initcall | usecs |")
    print("|---|---|---|")
    for i, (fn, us) in enumerate(rows[:20], 1):
        print("| %d | %s | %d |" % (i, fn, us))
    print("total=%d initcalls shown=%d — triage: slowest first (async_probe), then critical-chain head" % (len(rows), min(20, len(rows))))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
