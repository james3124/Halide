#!/bin/bash
# dump-abi.sh --out <dir> — dump current KMI artifacts from a built kernel (ch.03 S41).
# Real run needs out/<sku>/vmlinux + modules (abidump/genksyms): builder only. Guards out here.
set -eu
command -v abidw >/dev/null 2>&1 || command -v abidump >/dev/null 2>&1 || {
  echo "REFUSED: libabigail (abidw/abidump) not installed — kernel build tree + toolchain required."
  echo "Real logic (ch.03 S41):"
  echo "  1. abidump vmlinux -> <out>/abi.xml (libabigail vtable/layout dump)"
  echo "  2. genksyms per .ko + modules.order -> <out>/symbols.txt (allowlist + owner)"
  echo "  3. vermagic.txt + modules.order extracted from modules-staging"
  echo "  4. diff vs kernel/abi/<lts>/ baseline then scripts/abi-gate.py --kmi-enforcement 1"
  exit 2
}
echo "tooling present but full ABI dump not implemented in phone skeleton (builder-only, ch.03 S41)"
exit 2
