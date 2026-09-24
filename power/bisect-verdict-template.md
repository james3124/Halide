# Bisect verdict template (power-regression-bisect S2: MANIFEST deltas, not repos).
# Copy to power/bisect-<date>.md per completed bisect. Two culprits = split
# verdicts, no single-blame fiction. WA change without Arch+BSP sign invalidates.

Good-manifest: TODO (manifest-A)
Bad-manifest: TODO (manifest-B)
Scenario: TODO (suspend-8h --reps 2)
Blamed-commit: TODO (+ layer: kernel / HAL-blob / app-layer-bridge)
Signature: TODO (residency drop / DRX collapse / bridge CPU poll storm)
Confirm-commands-output:
  kernel: cat /sys/kernel/debug/wakeup_sources top diff: TODO (no new source >5min)
  hal: dumpsys power wake_lock + mmcli DRX check: TODO
  app-layer: systemd-cgtop + busctl poll-rate diff vs good: TODO
Both-reps-CSV: TODO (links, each rep beyond noise floor)
Wakeup-source-diff: TODO (attached)
Split-verdict-2 (if any): TODO
