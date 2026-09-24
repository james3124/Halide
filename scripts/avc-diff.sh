#!/bin/bash
# avc-diff.sh <baseline> <current> — per-domain new-denial counts (ch.08 §10 quarterly audit).
# Phone-safe: text diff of two avc log files. Exit 0 ok / 1 new denials over budget / 2 infra.
set -eu
BASE=${1:?usage: avc-diff.sh <baseline-avc.log> <current-avc.log>}; CUR=${2:?usage: avc-diff.sh <baseline-avc.log> <current-avc.log>}
[ -f "$BASE" ] && [ -f "$CUR" ] || { echo "REFUSED: log files not found"; exit 2; }

key() { grep -oE 'avc: *denied.*scontext=[^ ]+.*tcontext=[^ ]+.*tclass=[^ ]+' "$1" \
        | sed -E 's/.*scontext=([^ ]+).*tcontext=([^ ]+).*tclass=([^ ]+)/\1 \2 \3/' | sort -u; }
key "$BASE" > /tmp/avc-base.$$
key "$CUR" > /tmp/avc-cur.$$

new=$(comm -13 /tmp/avc-base.$$ /tmp/avc-cur.$$)
rm -f /tmp/avc-base.$$ /tmp/avc-cur.$$

if [ -z "$new" ]; then
  echo "AVC-DIFF OK: 0 new (scontext,tcontext,tclass) tuples vs baseline"
  exit 0
fi
n=$(echo "$new" | wc -l)
echo "NEW-DENIALS: $n tuple(s) — each needs a disposition within ch.08 §15 clocks:"
echo "$new" | head -20
echo "dispositions: ALLOW-WITH-RULE (6-step ladder) | MITIGATED-BY-CONFIG (rule named + test) | PRODUCT-BUG"
exit 1
