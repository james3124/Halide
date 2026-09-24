# plot-note.md - REF-A boot-chart plot artifact note (ch.03 S28/S29)
# Per release, commit the systemd plot next to the other capture set:
#   systemd-analyze plot > boot/refa/plot-6.6.30.svg
# (versioned per release: plot-<ver>.svg - committed, diffable.)
# Full capture set per release (sacrificial REF-A, same cable/charger/ambient
# note per ch.10 S8):
#   1. dmesg with initcall_debug (eng) -> scripts/initcall-rank.py ->
#      boot/refa/initcalls-<ver>.txt (S29).
#   2. systemd-analyze blame + critical-chain + plot.svg (this file's subject).
#   3. container boot_progress_* event deltas: logcat -b events slice
#      (ch.04 S5) for the container tail.
#   4. halide-boot-timeline merge: dmesg + journal + logcat boot_progress
#      into ONE csv (stage,ts_ms,source) - the single timeline everyone
#      argues from instead of three clocks (S28 instrumentation).
# WHY the plot is committed as SVG (S28): diffable across releases; the
# critical-chain head (the one unit everything waits on) is visible at a
# glance. Triage order is fixed: slowest initcall, then critical-chain head,
# then container tail (S29).
# Status: plot-6.6.30.svg pending first HW run (builder commits alongside the
# timeline CSV). This note pins the procedure so the artifact is not skipped.

# Verification
# - [ ] plot-<ver>.svg exists per release and opens as valid SVG.
# - [ ] blame top-15 deltas vs unit-budgets.txt reviewed (over-budget = entry).
# - [ ] timeline CSV archived with stage medians inside budget (Phase-1 gate).
