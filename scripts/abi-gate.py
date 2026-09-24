#!/usr/bin/env python3
# abi-gate.py — KMI gate over ABI dumps (ch.03 S41: UNCHANGED / ADDITIVE-ONLY / BREAK).
# Phone-safe: text diff of committed baseline vs dumped symbols; exits 2 without builder artifacts.
import argparse, os, sys


def read_lines(p):
    return set(l.strip() for l in open(p, encoding="utf-8", errors="replace")
               if l.strip() and not l.startswith("#"))


def main():
    ap = argparse.ArgumentParser(description="KMI gate (text-mode over symbols.txt diffs)")
    ap.add_argument("--baseline", required=True, help="kernel/abi/<lts>/ dir")
    ap.add_argument("--current", required=True, help="out/<sku>/abi-current/ dir")
    ap.add_argument("--kmi-enforcement", type=int, default=1)
    args = ap.parse_args()

    base_sym = os.path.join(args.baseline, "symbols.txt")
    cur_sym = os.path.join(args.current, "symbols.txt")
    for p in (base_sym, cur_sym):
        if not os.path.isfile(p):
            print("REFUSED: %s missing — kernel build-tree artifact, builder only (ch.03 S41)" % p)
            return 2

    base, cur = read_lines(base_sym), read_lines(cur_sym)
    removed = sorted(base - cur)
    added = sorted(cur - base)
    if removed:
        print("ABI-BREAK: %d removed symbol(s): %s" % (len(removed), ", ".join(removed[:5])))
        print("blessed-break MR shape: abidiff.txt + symbols-diff.txt + ABI-BREAK-JUSTIFICATION.md")
        return 1
    if added:
        print("ABI-ADDITIVE-ONLY: %d new symbol(s) — symbols.txt append needs owner + SINCE tag" % len(added))
        return 0
    print("ABI-UNCHANGED: symbols.txt identical (routine stable bump, triage row still required)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
