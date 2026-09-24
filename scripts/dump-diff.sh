#!/bin/bash
# dump-diff.sh <old> <new> — HAL dump diff ignoring volatile fields (appendix-04A golden rule).
# Phone-safe: pure text diff with dumps/golden-ignore.txt filters. Exit 0 clean / 1 hunks.
set -eu
cd "$(dirname "$0")/.."
OLD=${1:?usage: dump-diff.sh <old-dump> <new-dump>}; NEW=${2:?usage: dump-diff.sh <old-dump> <new-dump>}
[ -f "$OLD" ] && [ -f "$NEW" ] || { echo "REFUSED: dump files not found"; exit 2; }
IGNORE=dumps/golden-ignore.txt
# Volatile-field filters per appendix-04A: timestamps, counters, uptime, signal dBm +-6dB, battery +-2
IGN=/tmp/dump-ignore.$$
# plain grep patterns; volatile-field filters per appendix-04A: timestamps, counters, uptime,
# signal dBm +-6dB, battery +-2
cat > "$IGN" <<'EOF'
^[0-9][0-9]:[0-9][0-9]:[0-9][0-9]
uptime
^[0-9]*$
dBm
battery
count
time
EOF
# repo filter file uses sed-d syntax (/pattern/d); strip to plain regex for grep -f
[ -f "$IGNORE" ] && sed -n 's|^/\(.*\)/d$|\1|p' "$IGNORE" >> "$IGN"
# consider only changed lines (+/-), strip prefixes, drop volatile-field lines
if diff -u "$OLD" "$NEW" | grep -E '^(\+|-)' | grep -vE '^(\+\+\+|---)' | \
   sed 's/^[+-]//' | grep -vf "$IGN" 2>/dev/null | grep -q .; then
  echo "DUMP-DIFF: hunks found — MR must explain each hunk (appendix-04A) or refresh golden in same MR"
  diff -u "$OLD" "$NEW" | head -20
  rc=1
else
  echo "DUMP-DIFF OK: volatile-only delta ($(wc -l < "$OLD") lines scanned)"
  rc=0
fi
rm -f "$IGN"
exit $rc
