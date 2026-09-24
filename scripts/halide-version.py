#!/usr/bin/env python3
# halide-version.py — print/validate HALIDE build id `halide-<YYYYMMDD>-<sha12>` (ch.00 gate records).
# Phone-safe: pure string logic; git read-only if available. Exit 0 valid / 1 invalid / 2 usage.
import re, subprocess, sys
from datetime import date

PATTERN = re.compile(r"^halide-(\d{8})-([0-9a-f]{12})$")


def sha12():
    try:
        out = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True,
                             text=True, timeout=5, check=True)
        return out.stdout.strip()[:12]
    except Exception:
        return "000000000000"


def main(argv):
    if not argv or argv[0] in ("print", "--print"):
        print(f"halide-{date.today():%Y%m%d}-{sha12()}")
        return 0
    if argv[0] == "--check":
        if len(argv) < 2:
            print("usage: halide-version.py --check <id>", file=sys.stderr)
            return 2
        if PATTERN.match(argv[1]):
            return 0
        print(f"FAIL: {argv[1]!r} is not halide-<YYYYMMDD>-<sha12>", file=sys.stderr)
        return 1
    print("usage: halide-version.py [--check <id>|print]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
