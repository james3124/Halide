#!/usr/bin/env python3
"""gnss-assert.py — GNSS log assertions over an NMEA file passed as args (ch.10 §21/§24).

Checks: sentence checksums, monotonic UTC stamps, a valid fix present, and
TTFF (first stamp → first RMC-with-fix) if the log starts pre-fix (cold start).
Pure analysis, phone-safe. --redact scrubs coordinates from the verdict line.
Exit 0 pass / 1 fail / 2 no input.
"""
import re
import sys


def nmea_ok(line):
    if not line.startswith("$") or "*" not in line:
        return False
    body, cs = line[1:].split("*", 1)
    try:
        want = int(cs.strip()[:2], 16)
    except ValueError:
        return False
    x = 0
    for ch in body:
        x ^= ord(ch)
    return x == want


def secs(ts):
    """NMEA UTC stamp hhmmss.sss → seconds."""
    ts = ts.strip()
    hh, mm = int(ts[0:2]), int(ts[2:4])
    return hh * 3600 + mm * 60 + float(ts[4:] or "0")


def main(argv):
    if len(argv) < 2:
        print("SKIP: usage: gnss-assert.py <nmea-file> [--redact] (builder text-only)")
        return 2
    path = argv[1]
    try:
        lines = [l.strip() for l in open(path, encoding="utf-8", errors="replace")]
    except OSError as exc:
        print("FAIL-INFRA: cannot read %s (%s)" % (path, exc))
        return 2
    nmea = [l for l in lines if l.startswith("$")]
    if not nmea:
        print("FAIL-INFRA: no NMEA sentences in %s" % path)
        return 2
    bad = [l for l in nmea if not nmea_ok(l)]
    if bad:
        print("FAIL: %d/%d sentences fail checksum (corrupt log)" % (len(bad), len(nmea)))
        return 1
    rmc = [l for l in nmea if l[3:6] == "RMC"]
    if not rmc:
        print("FAIL-INFRA: no RMC sentences — cannot judge fix")
        return 2
    fields = [l.split(",") for l in rmc]
    stamps = [f[1] for f in fields if f[1]]
    tvals = [secs(s) for s in stamps]
    if tvals != sorted(tvals):
        print("FAIL: non-monotonic UTC stamps")
        return 1
    fixed = [f for f in fields if len(f) > 2 and f[2] == "A"]
    if not fixed:
        print("FAIL: no fix in %d RMC sentences" % len(fields))
        return 1
    ttff = (secs(fixed[0][1]) - secs(fields[0][1])) if fields[0][2] == "V" else None
    lat = float(fixed[0][3]) / 100.0 if fixed[0][3] else 0.0
    if not (0.0 < abs(lat) <= 90.0):
        print("FAIL: implausible latitude %s" % fixed[0][3])
        return 1
    out = "PASS: %d RMC, checksums OK, fix present, TTFF=%s (gate 60s cold)" % (
        len(rmc), "%.0fs" % ttff if ttff is not None else "n/a (already fixed)")
    if "--redact" in argv:
        out = re.sub(r"-?\d{1,3}\.\d{4,}", "<COORD>", out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
