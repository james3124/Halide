#!/bin/sh
# recovery/slot-check.sh - slot-surgery state dump (runbook-recovery S5).
# Phone-safe STUB: states the display + surgery rules, refuses to mark from here.
# Rules: after 2 consecutive failed health-gates offer "Mark slot BAD and stay" +
# "Copy current-good to staged repair" (one-tap each, both logged); bootctl state
# (is-marked-successful, tries-remaining) always shown - no hidden slot state.
set -eu
echo "slot-check plan (text only):"
echo "1. show both slots: versions + is-marked-successful + tries-remaining"
echo "2. switching to older warns ROLLBACK, allows with confirm (user owns risk)"
echo "3. after 2 failed health-gates: offer Mark-BAD-and-stay + Copy-good-to-repair"
echo "refusing to execute on phone: destructive + needs builder/fastboot" >&2
exit 2
