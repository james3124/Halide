# OPT-LOG.md - REF-A boot-time optimization ledger (ch.03 S28)
# Newest-first. Institutional memory of "we tried that": every entry carries
# before/after 5-boot medians on sacrificial REF-A (same charger/cable/ambient
# footnote per ch.10 S8) or it did not happen. Cold-boot numbers only; warm
# boots are labeled warm and never averaged into cold medians (S29).

## 2026-09-02 - SEED: ledger opened, no optimizations landed yet
- State: budgets from S7/S28 (ABL <=8s, kernel->systemd <=12s, systemd->login
  <=15s, container->boot_completed <=60s Phase-3, total <=45s cold-to-lock + 5s
  contingency). First 5-boot median set pending HW run; file TREND.csv then.
- Next candidates (in triage order per S29): slowest initcall first (see
  initcalls-6.6.30.txt seed), then systemd critical-chain head, then
  container tail via `logcat -b events` boot_progress deltas.
- WHY this file exists: S28 requires the ledger; S29 weekly boot-trend job
  pages the stage owner on >500ms week-over-week regression with ranked diff.

## Template for future entries (copy, do not improvise schema)
# Date - Title
# - Change: what moved (deferred-init list / modules-load.d order / ramdisk
#   trim / LZ4-vs-gzip / readahead-erofs tuning).
# - Before/after medians: stage + ms + 5-boot median + ambient footnote.
# - Tool proof: halide-boot-timeline CSV attached (stage,ts_ms,source).
# - Verdict: keep / revert + follow-up BUG id.

## Anti-patterns banned with prejudice (S28 - each learned once, written down)
1. Blocking network in `halide-android-prepare` (modem FW download retries
   stall boot). Fix: async with `--timeout 5` + degraded banner. Proof:
   unplugged-boot test (SIM-out + Wi-Fi-dead) still reaches lock within
   budget +10s.
2. Blanket `udev` settle-all. Fix: scoped waits (`Requires=sys-devices-...`
   device units). Every `sleep` in a boot-path script carries a WHY-NOT-EVENT
   comment or CI boot-lint fails it (S29).
3. Probing every panel variant sequentially at DTOVERLAY time. Fix: ID-read
   once, select JSON per ch.06 S11. Probe-all costs seconds (S28).
4. Averaging warm-cache boots into cold medians to flatter TREND.csv (S29).
   Cold = power-off >=60s, flash cold.

## LZ4-vs-gzip ramdisk position (SEED - measured numbers pending)
- Both numbers will be committed here before choosing: decompression time
  (ms, kernel->systemd stage) vs flash size (bytes vs flashmap.json budget).
  Assumed nothing; measured on REF-A sacrificial.

## Verification
- [ ] Every landed MR touching boot time references a dated entry here.
- [ ] `boot-budget-check` CI: any MR adding >500ms to any stage median fails
  without timeline CSV + justification.
