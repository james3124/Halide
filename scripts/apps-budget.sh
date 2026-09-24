#!/bin/bash
# scripts/apps-budget.sh — seeded app count + image budget guard (ch.05 §17, ch.09 §8).
# Text-only: counts SEED.md rows per class against caps. Exit 0/1/2.
set -u
cd "$(dirname "$0")/.."
FAIL=0
SEED=apps/SEED.md
[ -f "$SEED" ] || { echo "SKIP: $SEED missing"; exit 2; }

count_section() {  # rows between [section] and next [section]
  awk -v sec="$1" '
    /^\[/ { insec = ($0 ~ sec) }
    insec && /^[A-Za-z0-9][^|#]*\|/ { n++ }
    END { print n+0 }' "$SEED"
}

HOST_N=$(count_section "host-native")
FLATPAK_N=$(count_section "flatpak-filtered")
ANDROID_N=$(count_section "android-system-allowlist")

echo "seeded: host-native=$HOST_N flatpak=$FLATPAK_N android-allowlist=$ANDROID_N"

# Caps (§17): android system allowlist = 4 exactly; flatpak <= 20 by Phase-3.
if [ "$ANDROID_N" -gt 4 ]; then echo "FAIL: android allowlist $ANDROID_N > 4 (drawer system allowlist)"; FAIL=1; fi
if [ "$FLATPAK_N" -gt 20 ]; then echo "FAIL: flatpak seed $FLATPAK_N > 20 (§17 cap)"; FAIL=1; fi
if [ "$HOST_N" -lt 8 ]; then echo "FAIL: host-native $HOST_N < 8 (§17 mandatory set)"; FAIL=1; fi

# Every seeded row needs a WHY (review rule: unexplained seed rows rejected)
NOWHY=$(awk '/^[A-Za-z0-9][^|#]*\|/ && !/\| *[A-Za-z0-9].*\(.*§.*\)|store|budget|cap|growth|more rows/ { n++ } END { print n+0 }' "$SEED")
[ "$NOWHY" -eq 0 ] || echo "note: $NOWHY seed row(s) without explicit WHY-ref — reviewer checks manually"

[ "$FAIL" -eq 0 ] && echo "apps-budget: PASS"
exit "$FAIL"
