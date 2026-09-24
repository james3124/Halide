# dtb-disassembly-6.6.30.md - REF-A DTB disassembly review note (ch.03 S5)
# Owner: Kernel/BSP. Rule (S5): validate with dtc + fdtdump, run the fdt-rm
# fault-injection test (missing panel -> graceful framebuffer fallback, not
# panic), and commit the dtb disassembly diff per release for review.
# Builder procedure (containerized, S11 digest):
#   dtc -I dts -O dtb -o out/refa/base.dtb kernel/devices/refa/dts/base.dts
#   fdtdump out/refa/base.dtb > out/refa/base-6.6.30.fdtdump
#   fdtdump out/refa/merged.dtb > out/refa/merged-6.6.30.fdtdump   (S40 apply-verify)
#   diff -u <prev-release fdtdump> <this-release fdtdump> | tee out/refa/dtbo-applied.diff
#   # fault injection: fdt rm the panel node in a copy, boot sacrificial,
#   # expect framebuffer fallback + DTBO-MISSING banner (S40 layer 2/3), never panic.
# Expected review deltas: only intended nodes (regulator/panel/touch per S13
# checklist). Any chosen/bootargs or /memory delta = lint FAIL (overlays never
# touch those, S40). DT review rule: every overlay line has a comment with
# source (stock dump / datasheet page / measured); lines without provenance
# are rejected in review (S13).
# Status: disassembly artifacts pending first builder run (NO-COMPILE here);
# this note pins the procedure + expected outputs so the release cannot ship
# without them (Phase-1 gate: DT provenance review zero uncommented lines).

# Verification
# - [ ] base + merged fdtdump committed per release; diff shows intended nodes only.
# - [ ] fdt-rm panel fault-injection green (fallback, not panic).
# - [ ] dtbo-lint.py clean (provenance + no root overwrite + always-on justification).
