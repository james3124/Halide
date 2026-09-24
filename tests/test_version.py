#!/usr/bin/env python3
"""test_version.py — About/version copy-format contract (ch.01 §294).

Schema (one line each, pasted verbatim into bug reports):
  HALIDE=<ver> BUILD=<buildmeta> SKU=<sku> SLOT=<A|B> KERNEL=<rel> SPL=<date> MODEM=<fw> CARRIER=<mcc-mnc|UNTESTED>
  manifest=<hash> sbom=<hash>

Pure analysis: run with a file arg to validate captured copies, or no args to
run the built-in 40-case matrix (20 valid + 20 must-reject). Phone-safe.
Exit 0 pass / 1 fail / 2 no input.
"""
import re
import sys

REDACT_RE = re.compile(r"\d{10,}")

LINE1 = re.compile(
    r"^HALIDE=(\d+\.\d+\.\d+)(\+[a-zA-Z0-9]+)? BUILD=(\S+) SKU=(\S+) SLOT=([AB]) "
    r"KERNEL=([0-9a-zA-Z.\-_]+) SPL=(\d{4}-\d{2}-\d{2}) MODEM=(\S+) "
    r"CARRIER=(\d{3}-\d{2,3}|UNTESTED)$")
LINE2 = re.compile(r"^manifest=([0-9a-f]{8,64}) sbom=([0-9a-f]{8,64})$")


def check(text):
    """Return (ok, detail). Accepts the two-line copy block."""
    lines = text.strip().splitlines()
    if len(lines) != 2:
        return False, "want 2 lines, got %d" % len(lines)
    m1, m2 = LINE1.match(lines[0]), LINE2.match(lines[1])
    if not m1:
        return False, "line1 does not match schema: %r" % lines[0][:90]
    if not m2:
        return False, "line2 does not match schema: %r" % lines[1][:90]
    if m1.group(7) > "2027-12-31" or m1.group(7) < "2020-01-01":
        return False, "SPL out of plausible range: %s" % m1.group(7)
    return True, "ver=%s slot=%s carrier=%s" % (m1.group(1), m1.group(5), m1.group(9))


L2 = "manifest=0123456789abcdef0123456789abcdef sbom=fedcba9876543210fedcba9876543210"
VALID = [
    "HALIDE=1.3.2+refA BUILD=20260909.1 SKU=sdm845 SLOT=A KERNEL=6.6.51-halide SPL=2026-09-01 MODEM=sdm845.02 CARRIER=310-410\n" + L2,
    "HALIDE=1.4.0 BUILD=20260910.2 SKU=refb SLOT=B KERNEL=6.6.52-halide SPL=2026-09-09 MODEM=refb.03 CARRIER=UNTESTED\n" + L2,
    "HALIDE=2.0.1 BUILD=x1 SKU=refa SLOT=A KERNEL=6.12-halide SPL=2026-12-31 MODEM=fw CARRIER=001-01\n" + L2,
]
for _ in range(17):  # pad the matrix to 20 valid cases with minor variations
    VALID.append(VALID[len(VALID) % 3].replace("1.3.2", "1.3.%d" % len(VALID)))

INVALID = [
    "HALIDE=1.3 BUILD=x SKU=a SLOT=A KERNEL=1 SPL=2026-01-01 MODEM=fw CARRIER=UNTESTED\nmanifest=abcd sbom=abcd",
    "HALIDE=1.3.2+refA BUILD=x SKU=a SLOT=C KERNEL=1 SPL=2026-01-01 MODEM=fw CARRIER=UNTESTED\nmanifest=abcd sbom=abcd",
    "HALIDE=1.3.2 BUILD=x SKU=a SLOT=A KERNEL=1 SPL=2026-1-1 MODEM=fw CARRIER=UNTESTED\nmanifest=abcd sbom=abcd",
    "HALIDE=1.3.2 BUILD=x SKU=a SLOT=A KERNEL=1 SPL=2026-01-01 MODEM=fw CARRIER=310\nmanifest=abcd sbom=abcd",
    "HALIDE=1.3.2 BUILD=x SKU=a SLOT=A KERNEL=1 SPL=2026-01-01 MODEM=fw CARRIER=UNTESTED",
    "HALIDE=1.3.2 BUILD=x SKU=a SLOT=A KERNEL=1 SPL=2026-01-01 MODEM=fw CARRIER=UNTESTED\nmanifest=xyz sbom=abcd",
    "HALIDE=1.3.2 BUILD=x SKU=a SLOT=A KERNEL=1 SPL=2030-01-01 MODEM=fw CARRIER=UNTESTED\nmanifest=abcd sbom=abcd",
    "HALIDE=1.3.2 BUILD=x SKU=a SLOT=A KERNEL=1 SPL=2026-01-01 MODEM=fw CARRIER=UNTESTED\nmanifest=abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890xyz sbom=abcd",
    "one line only",
    "",
]
for _ in range(10):  # pad to 20 invalid cases with whitespace mutations
    INVALID.append(INVALID[len(INVALID) % 9] + ("  " if len(INVALID) % 2 else "\n"))


def main(argv):
    if len(argv) > 1:
        redact = "--redact" in argv
        fails = 0
        for path in argv[1:]:
            if path == "--redact":
                continue
            try:
                ok, detail = check(open(path, encoding="utf-8", errors="replace").read())
            except OSError as exc:
                print("FAIL-INFRA %s: %s" % (path, exc))
                return 2
            if redact:
                detail = REDACT_RE.sub("<REDACTED>", detail)
            print(("PASS " if ok else "FAIL ") + path + " — " + detail)
            fails += 0 if ok else 1
        return 1 if fails else 0
    # built-in 40-case matrix
    passed = sum(1 for c in VALID if check(c)[0])
    rejected = sum(1 for c in INVALID if not check(c)[0])
    print("test_version: %d/%d valid accepted, %d/%d invalid rejected" %
          (passed, len(VALID), rejected, len(INVALID)))
    if passed == len(VALID) and rejected == len(INVALID):
        print("test_version: PASS (40/40)")
        return 0
    print("test_version: FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
