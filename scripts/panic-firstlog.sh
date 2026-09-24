#!/bin/bash
# panic-firstlog.sh --class <class> --input <log> — print the class's first-log next command (ch.03 §31).
# Phone-safe: text extraction + static recipe table; never executes device probes.
set -eu
CLASS=""; INPUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --class) CLASS=${2:?}; shift 2 ;;
    --input) INPUT=${2:?}; shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$CLASS" ] && [ -n "$INPUT" ] || { echo "usage: panic-firstlog.sh --class <class> --input <panic.txt>"; exit 2; }
[ -f "$INPUT" ] || { echo "REFUSED: $INPUT not found"; exit 2; }

# first panic timestamp line
ts=$(grep -m1 -E '\[[ ]*[0-9]+\.[0-9]+\]|^[0-9]{4}-[0-9]{2}-[0-9]{2}T' "$INPUT" || echo "(no timestamp found)")
echo "first-log: $ts"

case "$CLASS" in
  NULL-DEREF|BAD-PTR) echo "next: decode_stacktrace.sh vmlinux < $INPUT ; addr2line -e vmlinux <pc>" ;;
  OOPS-CONTINUABLE)   echo "next: grep 'Tainted:' $INPUT — decode W (warned) / O (out-of-tree) / G (proprietary)" ;;
  BINDER-UAF)         echo "next: pair $INPUT with container 'logcat -b crash' (binder deaths span stacks)" ;;
  RCU-STALL)          echo "next: CPUs-stuck mask -> ftrace cpu_idle window + clk_summary held-vote dump" ;;
  HUNG-TASK)          echo "next: 'task <name> blocked' holder + sysrq-w stack; UFS err_stats or qrtr timeout adjacency" ;;
  SMMU-FAULT)         echo "next: smmu-audit.py on this dmesg — FAR/FSR/CB parse, do NOT binder-triage an IOMMU fault" ;;
  ROOT-MOUNT)         echo "next: early console-ramoops lines: VFS + dm-verity + avb verifiedbootstate (red-state refusal is policy)" ;;
  OOM-PANIC)          echo "next: Mem-Info + slabinfo + PSI lines from $INPUT (foreground-kill = P0 per ch.03 §34)" ;;
  SOFT-LOCKUP)        echo "next: locked-CPU stack + /proc/interrupts delta + wakeup_sources (IRQ storm check)" ;;
  STACK-OVERFLOW)     echo "next: allstacks + THREAD_SIZE audit (8K-vs-16K per LTS, kernel/abi/)" ;;
  NOT-KERNEL)         echo "next: journalctl -b -1 + logcat -b all (route OUT of kernel queue)" ;;
  *) echo "next: (unknown class — panic-classify.py first, or add a taxonomy row MR)" ;;
esac
