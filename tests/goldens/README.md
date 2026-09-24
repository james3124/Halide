# tests/goldens - versioned reference outputs (ch.10 S17: goldens rot, version the truth).
#
# Rule: no test compares against a golden that is not versioned with the code
# that produces it (golden + producer pinned together in the same MR).
# Layout: tests/goldens/<suite>/<sku>/ with GOLDEN.json per dir:
#   producer (script + args + MANIFEST.lock SHA + firmware SHAs + ambient/cell
#   profile), tolerance (pixel % / timing ms / current mA), expiry (goldens older
#   than 6 months or 2 releases require a re-validation stamp).
# Update protocol: producer lands first with old golden STALE-EXPECTED (CI
# informational <=7 days); regenerate on reference hardware (never QEMU-promoted);
# human side-by-side sign (QA + area owner); unreviewed --update-goldens fails CI.
# PNG goldens captured on the labeled reference unit at the recorded brightness
# (unmatched-brightness goldens banned); committed camera frames are lab
# test-cards only, never people; EXIF GPS stripped before commit.
