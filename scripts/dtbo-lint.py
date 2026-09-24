#!/usr/bin/env python3
# dtbo-lint.py — text lint of DT overlay fragments (ch.03 S13/S40: provenance + blast-radius rules).
# Phone-safe: pattern checks over devices/<sku> fragments; no dtc, no compile, no flash.
# Checks: /plugin/ present; provenance comment (stock|datasheet|measured); no root-property
# overwrite; regulator always-on lines carry a justification comment.
import glob, os, re, sys

PROV = re.compile(r"stock|datasheet|measured", re.I)
REG_ALWAYSON = re.compile(r"regulator-always-on")
COMMENT_ONLY = re.compile(r"^\s*(\*|/\*|//|#)")


def root_overwrites(text):
    """True if a property is assigned directly in the root node (depth 1).

    Fragment overlays (fragment@N { target ... __overlay__ { ... } }) nest all
    assignments at depth >= 3, so a naive `/ { ... =` regex false-fires on them.
    This scanner tracks brace depth and only flags `name =` lines at depth 1
    (node openings contain `{` and are not assignments).
    """
    depth = 0
    for line in text.splitlines():
        s = line.strip()
        if not s or COMMENT_ONLY.match(line):
            pass
        elif depth == 1 and "=" in s and "{" not in s:
            return True
        depth += line.count("{") - line.count("}")
    return False


def lint_file(path):
    errs = []
    text = open(path, encoding="utf-8", errors="replace").read()
    if "/plugin/" not in text:
        errs.append("missing /plugin/ directive")
    if not PROV.search(text):
        errs.append("no provenance comment (stock DT dump / datasheet / measured) — ch.03 S13")
    if root_overwrites(text):
        errs.append("root-property overwrite (/ { prop = ...) — overlays never touch root (ch.03 S40)")
    for i, line in enumerate(text.splitlines(), 1):
        if COMMENT_ONLY.match(line):
            continue  # rule/provenance comments may name the property without justifying it
        if REG_ALWAYSON.search(line) and not re.search(r"/\*.*\*/|//", line):
            errs.append(f"line {i}: regulator-always-on without justification comment")
    return errs


def main(argv):
    src = argv[argv.index("--src") + 1] if "--src" in argv else "kernel/devices/refa"
    files = sorted(glob.glob(os.path.join(src, "**", "*.dtso"), recursive=True)
                   + glob.glob(os.path.join(src, "**", "*overlay*.dts"), recursive=True))
    if not files:
        print(f"DTBO-LINT OK: 0 overlay fragments under {src} (nothing to lint yet)")
        return 0
    rc = 0
    for f in files:
        errs = lint_file(f)
        if errs:
            rc = 1
            for e in errs:
                print(f"FAIL: {f}: {e}")
        else:
            print(f"OK: {f}")
    print(f"DTBO-LINT: {len(files)} file(s), {'FAIL' if rc else 'clean'}")
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
