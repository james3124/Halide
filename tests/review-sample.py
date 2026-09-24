#!/usr/bin/env python3
"""review-sample.py — QA review sampling over dogfood daily-form files (ch.10 §10).

Given one or more form files (CSV: reboots,app_crashes,missed_calls,missed_sms,
battery_eod,photos_ok,worst_thing — header required), sample N rows with a seed
for the weekly bug-review agenda and assert every sampled row carries the
required fields (missing fields = form-quality FAIL, ch.10 §10).
Pure analysis, phone-safe. Exit 0 pass / 1 fail / 2 no input.
"""
import csv
import random
import re
import sys

REQUIRED = ["reboots", "app_crashes", "missed_calls", "missed_sms", "battery_eod", "worst_thing"]
P0 = ("unsolicited reboot", "missed MT call", "missed SMS", "thermal shutdown", "data detach")


def red(s, on):
    return re.sub(r"\d{10,}", "<REDACTED>", s) if on else s


def load(paths):
    rows = []
    for p in paths:
        try:
            for r in csv.DictReader(open(p, encoding="utf-8", errors="replace")):
                r["_file"] = p
                rows.append(r)
        except OSError as exc:
            print("FAIL-INFRA: %s (%s)" % (p, exc))
            sys.exit(2)
    return rows


def main(argv):
    redact = "--redact" in argv
    n, seed = 5, 0
    val_flags = ("--n", "--seed")
    skip_next = False
    files = []
    for a in argv[1:]:
        if skip_next:
            skip_next = False
            continue
        if a in val_flags:
            skip_next = True
            continue
        if a == "--redact":
            continue
        files.append(a)
    for i, a in enumerate(argv):
        if a == "--n" and i + 1 < len(argv):
            n = int(argv[i + 1])
        if a == "--seed" and i + 1 < len(argv):
            seed = int(argv[i + 1])
    if not files:
        print("SKIP: usage: review-sample.py [--n N] [--seed S] <form.csv...>")
        return 2
    rows = load(files)
    if not rows:
        print("SKIP: no form rows found in %s" % files)
        return 2
    # P0 rows are never "sampled away" — they are all reviewed (ch.10 §10 rule)
    p0 = [r for r in rows if any(p in (r.get("worst_thing") or "").lower() for p in P0)
          or (r.get("reboots") or "0").strip() not in ("0", "", None)]
    rest = [r for r in rows if r not in p0]
    rng = random.Random(seed)
    sample = p0 + rng.sample(rest, min(n, len(rest)))
    fails = 0
    for r in sample:
        missing = [f for f in REQUIRED if not (r.get(f) or "").strip()]
        if missing:
            print("FAIL %s: missing fields %s" % (r["_file"], ",".join(missing)))
            fails += 1
        else:
            print("sample: %s reboots=%s crashes=%s battery_eod=%s worst=%s" %
                  (r["_file"], r["reboots"], r["app_crashes"], red(r["battery_eod"], redact),
                   red(r["worst_thing"], redact)[:40]))
    print("review-sample: %d/%d sampled rows complete (seed=%d)" %
          (len(sample) - fails, len(sample), seed))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
