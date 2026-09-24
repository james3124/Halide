#!/bin/sh
# halide-crash-banner.sh -- crash-banner arm/fire hook (ch.05 section 2).
# Lives in hybrid/debian-hooks/ (runs on device via halide-crash-banner.service
# and the container crash path). 3 rapid crashes stop auto-restart; Phosh shows
# "Android unavailable" + one-tap log export (never boot-loops the phone).
# Exit contract: 0 state updated / 1 crash threshold hit (banner fired) / 2 skip.
set -eu
STATE=/run/halide/crash-banner.state
COUNT=/run/halide/crash-count
MODE="${1:---arm}"
mkdir -p /run/halide

case "$MODE" in
  --arm)
    echo "armed $(date -u +%FT%TZ)" > "$STATE"
    echo "0" > "$COUNT"
    echo "halide-crash-banner: armed"
    exit 0
    ;;
  --fired)
    n="$(cat "$COUNT" 2>/dev/null || echo 0)"
    n=$((n + 1))
    echo "$n" > "$COUNT"
    echo "fired:$(date -u +%FT%TZ):count=$n" > "$STATE"
    if [ "$n" -ge 3 ]; then
      echo "Android unavailable - Export logs" > /run/halide/degraded-banner
      echo "halide-crash-banner: threshold hit ($n crashes), banner fired"
      exit 1
    fi
    echo "halide-crash-banner: crash $n recorded (threshold 3)"
    exit 0
    ;;
  --clear)
    echo "armed $(date -u +%FT%TZ)" > "$STATE"
    echo "0" > "$COUNT"
    rm -f /run/halide/degraded-banner
    echo "halide-crash-banner: cleared"
    exit 0
    ;;
  *)
    echo "usage: $0 [--arm|--fired|--clear]" >&2
    exit 1
    ;;
esac
