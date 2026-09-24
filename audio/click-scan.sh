#!/bin/bash
# click-scan.sh — phone-safe text scan of audio/<sku>/*.conf gain values (ch.04 audio gains).
# Purpose: catch gain values out of range [0.0..2.0] before they ship to the DSP; no audio
# device is opened, no tinymix/aplay run — text plan only (NO-COMPILE build mode).
# Exit contract: 0 = all in range, 1 = out-of-range value found, 2 = refused/infra (missing dir).
set -eu
cd "$(dirname "$0")/.."

AUDIODIR=audio/refa
[ -d "$AUDIODIR" ] || { echo "SKIP-INFRA: $AUDIODIR missing (no SKU gains in tree)"; exit 2; }

rc=0
for f in "$AUDIODIR"/*.conf; do
  [ -f "$f" ] || continue
  # scan only key=value gain lines (handset/speaker/bt/media_*), comments ignored
  while IFS='=' read -r key val; do
    case "$key" in
      \#*|"") continue ;;
    esac
    case "$key" in
      handset|speaker|bt|media_default|media_*) ;;
      *) continue ;;
    esac
    case "$val" in
      ''|*[!0-9.]*) echo "FAIL: $f: $key='$val' not numeric"; rc=1; continue ;;
    esac
    in_range=$(awk -v v="$val" 'BEGIN{print (v+0 >= 0.0 && v+0 <= 2.0) ? 1 : 0}')
    if [ "$in_range" -ne 1 ]; then
      echo "FAIL: $f: $key=$val out of range [0.0..2.0]"
      rc=1
    fi
  done < "$f"
done

if [ "$rc" -eq 0 ]; then
  echo "click-scan: PASS (all gains in [0.0..2.0])"
else
  echo "click-scan: FAIL — fix gains in $AUDIODIR before carrier sample sign-off (measurements.md)"
fi
exit "$rc"
