#!/usr/bin/env python3
# touch-stats.py — p50/p90/p95/max latency from a touch-latency CSV (ch.06 S7/S30 method).
# Purpose: phone-safe text tool — reads a CSV arg, prints a stats table, no device access.
# Usage: python3 touch-stats.py <touch-latency.csv>
# Exit contract: 0 = stats printed, 1 = bad CSV (parse/missing columns), 2 = usage error.
import csv
import sys


def percentile(sorted_vals, p):
    # linear interpolation (stats_v2, pinned so releases are comparable, ch.06 S30)
    if not sorted_vals:
        return 0.0
    pos = p / 100.0 * (len(sorted_vals) - 1)
    lo = int(pos)
    hi = min(lo + 1, len(sorted_vals) - 1)
    frac = pos - lo
    return sorted_vals[lo] + frac * (sorted_vals[hi] - sorted_vals[lo])


def main(argv):
    if len(argv) != 2 or argv[1] in ("-h", "--help"):
        print("usage: touch-stats.py <touch-latency.csv>", file=sys.stderr)
        return 2
    path = argv[1]
    latencies = []
    with open(path, newline="") as f:
        rows = csv.reader(f)
        header_seen = False
        for row in rows:
            if not row or (row and row[0].startswith("#")):
                continue
            if not header_seen:
                # ch.06 S30 normative column is delta_ms; latency_ms accepted as alias
                # (older runs + SEQ-join template used latency_ms — same definition).
                if "seq" not in row or ("latency_ms" not in row and "delta_ms" not in row):
                    print(f"FAIL: expected SEQ-join header (seq,...,delta_ms|latency_ms), got {row}", file=sys.stderr)
                    return 1
                lat_idx = row.index("latency_ms") if "latency_ms" in row else row.index("delta_ms")
                header_seen = True
                continue
            try:
                latencies.append(float(row[lat_idx]))
            except (ValueError, IndexError):
                print(f"FAIL: bad latency row: {row}", file=sys.stderr)
                return 1
    if not latencies:
        print("FAIL: no data rows", file=sys.stderr)
        return 1
    vals = sorted(latencies)
    n = len(vals)
    print(f"file        {path}")
    print(f"N           {n}")
    print(f"p50         {percentile(vals, 50):.1f} ms")
    print(f"p90         {percentile(vals, 90):.1f} ms")
    print(f"p95         {percentile(vals, 95):.1f} ms")
    print(f"max         {vals[-1]:.1f} ms")
    gate = "PASS p95<100 (ch.06 S7)" if percentile(vals, 95) < 100.0 else "FAIL p95>=100"
    print(f"verdict     {gate}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
