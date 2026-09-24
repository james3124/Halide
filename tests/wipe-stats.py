#!/usr/bin/env python3
"""wipe-stats.py — flash-wear aging math (ch.10 §15): write amplification from
two /sys/block snapshots or a committed stats file passed as args.

Input (text, key=value per line, two sections or two files):
  sectors_written=<n>        (from /sys/block/*/stat field 9 sum)
  userdata_written_mb=<n>    (host-visible user-data delta, df before/after)
WA = sectors_written / userdata_written_mb; sane range 1.0–8.0 (above 8: file).
Pure analysis, phone-safe. Exit 0 pass / 1 fail / 2 no input.
"""
import re
import sys


def parse(path_or_text):
    d = {}
    if path_or_text.strip().startswith(("sectors", "userdata")) or "=" in path_or_text.splitlines()[0]:
        text = path_or_text
    else:
        text = open(path_or_text, encoding="utf-8", errors="replace").read()
    for line in text.splitlines():
        if "=" in line and not line.strip().startswith("#"):
            k, v = line.split("=", 1)
            k = k.strip()
            if k in ("sectors_written", "userdata_written_mb"):
                d[k] = float(v.strip())
    return d


def red(s, on):
    return re.sub(r"\d{10,}", "<REDACTED>", s) if on else s


def main(argv):
    redact = "--redact" in argv
    files = [a for a in argv[1:] if not a.startswith("--")]
    if not files:
        print("SKIP: usage: wipe-stats.py <stats.txt | stats-before.txt stats-after.txt> [--redact]")
        return 2
    try:
        if len(files) == 1:
            stats = parse(open(files[0], encoding="utf-8", errors="replace").read())
        else:
            b, a = parse(open(files[0]).read()), parse(open(files[1]).read())
            stats = {k: a.get(k, b.get(k, 0)) - b.get(k, 0) for k in ("sectors_written", "userdata_written_mb")}
    except (OSError, ValueError) as exc:
        print("FAIL-INFRA: cannot read/parse input (%s)" % exc)
        return 2
    if "sectors_written" not in stats or "userdata_written_mb" not in stats:
        print("FAIL-INFRA: need sectors_written + userdata_written_mb keys")
        return 2
    if stats["userdata_written_mb"] <= 0:
        print("FAIL-INFRA: zero/negative user-data delta — comparison windows invalid (§15)")
        return 2
    wa = stats["sectors_written"] / (stats["userdata_written_mb"] * 2048.0)  # 512B sectors per MB
    print(red("wipe-stats: WA=%.2f (sectors=%d, userdata=%.0f MB)" %
              (wa, stats["sectors_written"], stats["userdata_written_mb"]), redact))
    if wa < 1.0:
        print("FAIL: WA < 1.0 — accounting bug (sectors understated or windows mismatched)")
        return 1
    if wa > 8.0:
        print("FAIL: WA > 8.0 — file-system layer thrashing; investigate before RC (§15)")
        return 1
    print("wipe-stats: PASS (WA within sane band 1.0–8.0)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
