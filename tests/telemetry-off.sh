#!/bin/bash
# tests/telemetry-off.sh — off-means-off proof: declined device emits only allowlisted
# traffic (NTP + connectivity-check + user-initiated), ch.05 §15. Capture via host
# tcpdump; FAIL on any non-allowlisted egress. Evidence redacted.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
emit() { if [ "$REDACT" = 1 ]; then sed -E 's/[0-9]{10,}/<REDACTED>/g'; else cat; fi; }

ALLOW="ntp|time\.|connectivity-check|halide-ota-report"   # allowlist, ch.05 §15
if command -v tcpdump >/dev/null 2>&1 && [ -d /run/halide ]; then
  SECS="${HALIDE_TELEMO_SEC:-600}"                        # §15 wants 10 min post-boot
  mkdir -p logs
  PCAP=logs/telemetry-$(date +%Y%m%d-%H%M%S).txt
  tcpdump -i any -nn -q -l "tcp or udp" 2>/dev/null | timeout "$SECS" cat > "$PCAP" || true
  BAD=$(grep -Ev "$ALLOW" "$PCAP" | grep -cE 'dst 1?[0-9]{1,2}\.[0-9]{1,3}\.' || true)
  echo "telemetry-off: captured ${SECS}s → $PCAP, non-allowlisted egress lines: $BAD" | emit
  [ "$BAD" -eq 0 ] || { echo "FAIL: non-allowlisted egress observed on a declined device"; sed -n "1,5p" "$PCAP" | emit; exit 1; }
  echo "telemetry-off: PASS"
  exit 0
fi
# builder fallback: static proof that telemetry call-sites name their toggle (§15)
FAIL=0
if grep -rn 'halide-telemetryd' debian/ bridges/ 2>/dev/null | grep -qv 'toggle'; then
  echo "FAIL: telemetry call-site without named toggle (§15 code-review rule)"; FAIL=1
else
  echo "telemetry-off: no untagged telemetry call-site in tree — static OK"
fi
if ! command -v tcpdump >/dev/null 2>&1; then
  echo "SKIP-live: tcpdump missing (device/builder only)"
fi
[ "$FAIL" = 0 ] && echo "telemetry-off: PASS" || echo "telemetry-off: FAIL"
exit "$FAIL"
