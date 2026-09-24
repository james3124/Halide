#!/bin/bash
# decode_stacktrace.sh — wrap the kernel tree's decode_stacktrace with vmlinux (ch.03 §31 first-log).
# Phone-safe: needs a built kernel tree (vmlinux) — guards out on phone with exit 2.
set -eu
VMLINUX=${1:?usage: decode_stacktrace.sh <vmlinux> [stack.log]}

# locate the tool: kernel tree layout on builder, else REFUSE (no compile here either way)
TOOL=""
for t in kernel/linux/scripts/decode_stacktrace scripts/decode_stacktrace; do
  [ -x "$t" ] && TOOL="$t" && break
done
if [ -z "$TOOL" ]; then
  echo "REFUSED: no scripts/decode_stacktrace in a kernel tree on this device (builder only, NO-COMPILE)."
  echo "On builder: ./scripts/decode_stacktrace.sh vmlinux < stack.log  -> file:line annotated oops"
  echo "then: addr2line -e vmlinux <pc> for the NULL-DEREF class (ch.03 §31 table row 1)."
  exit 2
fi
[ -f "$VMLINUX" ] || { echo "REFUSED: vmlinux $VMLINUX not found"; exit 2; }
exec "$TOOL" "$@"
