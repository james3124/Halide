#!/bin/bash
# tests/qmi-redact.sh — QMI/AT log redaction audit (ch.07 §7, ch.01 §294): scans a log
# for raw IMSI/IMEI/MSISDN patterns; --redact prints the redacted view. No arg = skip.
# Phone-safe: pure text analysis; never mutates logs.
# DOD: DoD-logs
set -eu
cd "$(dirname "$0")/.."
F="${1:-}"
[ -n "$F" ] || { echo "SKIP: usage: qmi-redact.sh <qmi-or-at-logfile> [--redact] (builder text-only)"; exit 2; }
[ -f "$F" ] || { echo "SKIP: log file not found: $F (builder text-only)"; exit 2; }
REDACT=0; for a in "$@"; do [ "$a" = "--redact" ] && REDACT=1; done
# patterns: 15-digit IMEI, 15-digit IMSI (310…/001… style), MSISDN E.164 bodies
IMEI=$(grep -oE '\b[0-9]{15}\b' "$F" | sort -u | wc -l)
IMSI=$(grep -oE '\bIMS[Ii][=: ]*[0-9]{14,16}\b' "$F" | wc -l)
MSISDN=$(grep -oE '\+\d{11,15}' "$F" | sort -u | wc -l)
echo "qmi-redact: $F → raw-15digit=$IMEI imsi-fields=$IMSI msisdn=$MSISDN"
if [ "$REDACT" = 1 ]; then
  sed -E 's/\b[0-9]{10,}\b/<REDACTED>/g' "$F"
  echo "qmi-redact: redacted view emitted (--redact)"
  exit 0
fi
if [ "$IMEI" -eq 0 ] && [ "$IMSI" -eq 0 ] && [ "$MSISDN" -eq 0 ]; then
  echo "qmi-redact: no raw identifiers found — log is safe to commit — PASS"
  exit 0
fi
echo "FAIL: $((IMEI+IMSI+MSISDN)) unredacted identifier(s) in $F — commit the redacted view only (ch.07 §7)"
exit 1
