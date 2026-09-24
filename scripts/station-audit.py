#!/usr/bin/env python3
# station-audit.py — factory flash-station audit (ch.09 S16/S30: station docs + nftables isolation).
# Phone-safe: reads factory/*.md + nftables conf text; redacted logs only, never raw serials.
import glob, os, sys

FACT = "factory"


def main():
    if not os.path.isdir(FACT):
        print("REFUSED: %s/ missing" % FACT)
        return 2
    stations = sorted(glob.glob(os.path.join(FACT, "station-*.md")))
    rc = 0
    if not stations:
        print("FAIL: no station-*.md in %s/ (one per flash station, ch.09 S16)" % FACT)
        rc = 1
    for s in stations:
        if os.path.getsize(s) == 0:
            print("FAIL: %s empty" % s)
            rc = 1
        else:
            print("OK: %s" % s)

    nft = None
    for cand in sorted(glob.glob(os.path.join(FACT, "*.conf"))) + \
                sorted(glob.glob(os.path.join(FACT, "*.nft"))) + \
                sorted(glob.glob(os.path.join("security", "nft*.conf"))):
        if os.path.getsize(cand) > 0:
            nft = cand
            break
    if nft is None:
        print("FAIL: no non-empty nftables conf (station VLAN isolation, ch.09 S16)")
        rc = 1
    else:
        print("OK: nftables conf %s (%d lines)" % (nft, sum(1 for _ in open(nft))))

    print("STATION-AUDIT: %s" % ("FAIL" if rc else "PASS"))
    return rc


if __name__ == "__main__":
    sys.exit(main())
