# kernel/tests - KUnit suites for carried drivers (ch.03 S23)
# Owner: Kernel/BSP. New driver without KUnit = review fail (S22 checklist
# cites S23). Suites run in CI via tools/testing/kunit/kunit.py run
# --arch=arm64 on the defconfig+fragment combo (S11 build produces the same
# .config CI tests - no separate test-config drift).
# Required coverage per suite: probe-success/fail paths (missing IRQ ->
# -EPROBE_DEFER, not oops), suspend/resume callbacks (balanced pm_runtime
# gets/puts asserted), DT-parse of malformed properties (wrong #cells ->
# graceful -EINVAL).
# Files: Kconfig + Makefile wire the four suites; each .c is a kunit stub
# with the three mandated test cases shaped for the real driver struct.
# CONFIG_FUZZ companion: syzkaller descriptions in kernel/syzkaller/
# (binderfs-mount-options.syz, dt-overlay-parser.syz) run nightly 30-min on
# VIRT-arm64 (S23); syzkaller findings in carried code fixed-or-reverted
# within the 30-day clock (S23/ch.08 S15 bins).
